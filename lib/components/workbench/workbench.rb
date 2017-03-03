# frozen_string_literal: true
module TaskVault
  class Workbench < ServerComponent
    attr_valid_dir :path, allow_nil: true, serialize: true, always: true
    attr_bool :recursive, default: true, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 60, serialize: true, always: true
    attr_sym :vault_name, default: :vault, serialize: true, always: true
    attr_reader :recipes

    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      super
    end

    def self.description
      'Task management, made easy. Workbench works with Vault to provide a mechanism to serialize tasks ' \
      'to disk as well as load them from disk. It also allows those saved files to be modified and make ' \
      'changes to the currently running tasks. Be sure you have a vault in your server, ' \
      'otherwise Workbench will get lonely.'
    end

    def vault
      @parent.components[@vault_name]
    end

    def add(recipe)
      recipe = recipe.serialize if recipe.is_a?(Task)
      raise ArgumentError, 'Recipes must contain a name field.' unless recipe[:name]
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
      vault.add(@recipes[recipe[:name].to_sym][:task])
      recipe[:name].to_sym
    end

    alias add_recipe add

    def save(name, format: :yaml)
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
        File.exist?(path)
      else
        queue_msg("Failed to save recipe #{name} because it does not exist!", severity: :warn)
        false
      end
    end

    def save_all(format: :yaml)
      queue_msg("Saving all recipes in workbench to #{@path}: #{@recipes.size} total.", severity: :debug)
      @recipes.each do |name, _data|
        save(name, format: format)
      end
    end

    def remove(name)
      return unless @recipes.include?(name)
      queue_msg("Removing recipe '#{name}' from Workbench.", severity: :info)
      @recipes.delete(name)[:task].cancel
    end

    def delete(name)
      remove(name)
      BBLib.scan_files(@path, '*.json', '*.yml', '*.yaml', recursive: true).map do |file|
        queue_msg("Deleting recipe file on disk for '#{name}': #{file}", severity: :info)
        File.delete(file)
      end
    end

    def load_recipes(_path = @path)
      BBLib.scan_files("#{@path}/recipes/".pathify, '*.yaml', '*.yml', '*.json', recursive: @recursive).map do |file|
        begin
          recipe = YAML.load_file(file) if file.end_with?('.yml', '.yaml')
          recipe = JSON.parse(File.read(file)) if file.end_with?('.json')
          add(recipe)
        rescue StandardError => e
          queue_msg e, severity: :error
          queue_msg(
            "Workbench failed to construct task from file '#{file}'. " \
            'It will not be added to the task queue or workbench.',
            severity: :warn
          )
        end
      end
    end

    protected

    def setup_defaults
      @recipes = {}
    end

    def run
      loop do
        start = Time.now
        queue_msg('Workbench is now reloading recipes from disk.', severity: :debug)
        current_recipes = load_recipes
        @recipes.each do |name, _data|
          remove(name) unless current_recipes.include?(name)
        end
        sleep_time = @interval - (Time.now.to_f - start.to_f)
        queue_msg(
          "Workbench is finished loading recipes from disk. Currently managing #{@recipes.size} total recipes. " \
          "Next run is in #{sleep_time.to_duration}.",
          severity: :debug
        )
        sleep(sleep_time.zero? ? 0 : sleep_time)
      end
    end

    def changed?(task, new_recipe)
      if recipe = @recipes[task.name]
        recipe[:recipe] != new_recipe
      else
        true
      end
    end
  end
end
