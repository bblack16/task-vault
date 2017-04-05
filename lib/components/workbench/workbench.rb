# frozen_string_literal: true
require_relative 'api'

module TaskVault
  class Workbench < ServerComponent
    attr_valid_dir :path, allow_nil: true, serialize: true, always: true
    attr_bool :recursive, default: true, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 60, serialize: true, always: true
    attr_sym :vault_name, default: :vault, serialize: true, always: true
    attr_int :id, default: -1, serialize: true, always: true
    attr_reader :recipes

    def start
      queue_info('Starting up component.')
      super
    end

    def stop
      queue_info('Stopping component.')
      super
    end

    def self.description
      'Workbench allows tasks to be loaded from disk. It also ensures changes to those ' \
      'files automatically update the currently running tasks. Workbench needs a running instance ' \
      'of vault to be useful.'
    end

    def vault
      parent.component(vault_name)
    end

    def read(file)
      recipe = YAML.load_file(file) if file.end_with?('.yml', '.yaml')
      recipe = JSON.parse(File.read(file)) if file.end_with?('.json')
      raise ArgumentError, "#{file} does not appear to be a valid recipe type." unless recipe
      if existing = recipes[file]
        if existing[:recipe] != recipe
          existing[:task].reload(recipe)
          queue_info("Task #{existing[:task].name} has been updated and reloaded.")
        end
      else
        recipes[file] = { recipe: recipe, task: Task.load(recipe.dup), id: next_id }
        queue_info("New task '#{recipes[file][:task].name}' has been added.")
      end
      vault.add(recipes[file][:task])
    end

    alias reload load

    def add(hash, format: :yaml)
      hash = hash.serialize if Hash.is_a?(Task)
      raise ArgumentError, "Invalid format '#{format}'. Must be :yaml or :json." unless [:yaml, :json].include?(format)
      raise ArgumentError, 'You must pass a hash to save a new workbench item.' unless hash.is_a?(Hash)
      raise ArgumentError, 'Your recipe must containg a name.' unless hash[:name]
      path = "#{@path}/recipes/#{hash[:name]}".pathify
      queue_info("Saving task #{name} at #{path}.#{format}")
      hash.send("to_#{format}").to_file(path, mode: 'w')
      read(path)
    end

    alias add_recipe add

    def recipe(id)
      recipe = recipes.find { |_k, v| v[:id] == id }
      return unless recipe
      [recipe].to_h
    end

    def remove(name)
      return unless @recipes.include?(name) 
      queue_msg("Removing recipe '#{name}' from Workbench.", severity: :info)
      @recipes.delete(name)[:task].cancel
    end

    def delete(file)
      remove(file)
      File.delete(file)
      !File.exist?(file) && !recipes[file]
    end

    def load_recipes
      BBLib.scan_files("#{path}/recipes/".pathify, '*.yaml', '*.yml', '*.json', recursive: @recursive).map do |file|
        begin
          read(file)
        rescue => e
          queue_warn("Workbench failed to construct task from file '#{file}'. It will not be added to the task queue or workbench")
          queue_error(e)
        end
      end
    end

    protected

    def setup_defaults
      @recipes = {}
    end

    def next_id
      @id += 1
    end

    def run
      loop do
        start = Time.now
        if @path && Dir.exist?("#{@path}/recipes")
          queue_msg('Workbench is now reloading recipes from disk.', severity: :debug)
          load_recipes
          @recipes.each do |file, _data|
            remove(file) unless File.exist?(file)
          end
          queue_debug("Workbench is finished loading recipes from disk. Currently managing #{@recipes.size} total #{BBLib.pluralize(@recipes.size, 'recipe')}.")
        else
          queue_warn("#{@path} does not exist. No recipes will be loaded...")
        end
        sleep_time = @interval - (Time.now.to_f - start.to_f)
        sleep(sleep_time.zero? ? 0 : sleep_time)
      end
    end
  end
end
