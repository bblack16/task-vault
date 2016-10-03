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
      raise ArgumentError, "Recipes must contain a name field." unless recipe[:name]
      if existing = @recipes[recipe[:name]]
        if existing[:recipe] != recipe
          existing[:task].reload(recipe)
          queue_msg("Task #{recipe[:name]} has been updated and reloaded.", severity: :info)
        end
      else
        @recipes[recipe[:name]] = { recipe: recipe, task: Task.load(recipe) }
        queue_msg("New task '#{recipe[:name]}' has been added.", severity: :info)
      end
      @parent.vault.add(@recipes[recipe[:name]][:task])
    end

    alias_method :add_recipe, :add

    def save name, format: :yaml
      if recipe = @recipes[name]
        task = recipe[:task]
        path = "#{@path}/recipes/#{task.name}".pathify
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
        false
      end
    end

    def save_all format: :yaml
      @recipes.each do |name, data|
        save(name, format: format)
      end
    end

    def remove name
      @recipes.delete(name)
    end

    def delete name
      remove(name)
      BBLib::scan_files(@path, filter: ['*.json', '*.yml', '*.yaml'], recursive: true).map do |file|
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
          load_recipes
          sleep_time = @interval - (Time.now.to_f - start.to_f)
          queue_msg("Workbench is finished loading recipes from disk. Next run is in #{sleep_time.to_duration}.", severity: :debug)
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
