module TaskVault

  class Workbench < Component
    attr_valid_dir :path, allow_nil: true
    attr_bool :recursive, default: true
    attr_float_between 0.001, nil, :interval, default: 60
    attr_reader :recipes

    def start
      queue_msg("Starting up component.", severity: :info)
      super
    end

    def stop
      queue_msg("Stopping component.", severity: :info)
      super
    end

    def add recipe
      recipe = recipe.serialize if recipe.is_a?(Task)
      p recipe
      raise ArgumentError, "Recipes must contain a name field." unless recipe[:name]
      if existing = @recipes[recipe[:name].to_sym]
        if existing[:recipe] != recipe
          existing[:task].reload(recipe)
          queue_msg("Task #{recipe[:name]} has been updated and reloaded.", severity: :info)
        end
      else
        @recipes[recipe[:name].to_sym] = { recipe: recipe, task: Task.load(recipe.dup) }
        queue_msg("New task '#{recipe[:name]}' has been added.", severity: :info)
        save(recipe[:name].to_sym)
      end
      @parent.vault.add(@recipes[recipe[:name].to_sym][:task])
      recipe[:name].to_sym
    end

    alias_method :add_recipe, :add

    def save name, format: :yml
      if recipe = @recipes[name.to_sym]
        task = recipe[:task]
        path = "#{@path}/recipes/#{task.name}".pathify
        queue_msg("Saving task #{name} at #{path}.#{format}", severity: :debug)
        case format
        when :yaml, :yml
          path += '.yml'
          task.serialize.to_yaml.to_file(path, mode: 'w')
        when :json
          path += '.json'
          task.serialize.to_json.to_file(path, mode: 'w')
        else
          raise ArgumentError, "Invalid format '#{format}'. Must be :yaml or :json."
        end
        File.exists?(path)
      else
        queue_msg("Failed to save recipe #{name} because it does not exist!", severity: :warn)
        false
      end
    end

    def save_all format: :yaml
      queue_msg("Saving all recipes in workbench to #{@path}: #{@recipes.size} total.", severity: :debug)
      @recipes.each do |name, data|
        save(name, format: format)
      end
    end

    def remove name
      if @recipes.include?(name)
        queue_msg("Removing recipe '#{name}' from Workbench.", severity: :info)
        @recipes.delete(name)[:task].cancel
      end
    end

    def delete name
      remove(name)
      BBLib::scan_files(@path, filter: ['*.json', '*.yml', '*.yaml'], recursive: true).map do |file|
        queue_msg("Deleting recipe file on disk for '#{name}': #{file}", severity: :info)
        File.delete(file)
      end
    end

    def load_recipes path = @path
      BBLib.scan_files( "#{@path}/recipes/".pathify, filter: ['*.yaml', '*.yml', '*.json'], recursive: @recursive).map do |file|
        begin
          recipe = YAML.load_file(file) if file.end_with?('.yml') || file.end_with?('.yaml')
          recipe = JSON.parse(File.read(file)) if file.end_with?('.json')
          add(recipe)
        rescue StandardError => e
          queue_msg e, severity: :error
          queue_msg "Workbench failed to construct task from file '#{file}'. It will not be added to the task queue or workbench.", severity: :warn
        end
      end
    end

    protected

      def setup_defaults
        @recipes = Hash.new
      end

      def run
        loop do
          start = Time.now
          queue_msg("Workbench is now reloading recipes from disk.", severity: :debug)
          current_recipes = load_recipes
          @recipes.each do |name, data|
            remove(name) unless current_recipes.include?(name)
          end
          sleep_time = @interval - (Time.now.to_f - start.to_f)
          queue_msg("Workbench is finished loading recipes from disk. Currently managing #{@recipes.size} total recipes. Next run is in #{sleep_time.to_duration}.", severity: :debug)
          sleep(sleep_time < 0 ? 0 : sleep_time)
        end
      end

      def changed? task, new_recipe
        if recipe = @recipes[task.name]
          recipe[:recipe] != new_recipe
        else
          true
        end
      end

  end

end
