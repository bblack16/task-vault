module TaskVault
  class Workbench
    include Runnable
    include BBLib::Prototype

    attr_ary_of String, :paths
    attr_bool :recursive, default: true
    attr_hash :recipes, protected_writer: true

    def overseer
      return nil unless parent
      parent.components.find { |component| component.is_a?(Overseer) }
    end

    def process(file)
      if exist?(file)
        task = overseer.find(recipes[file][:id])
        return task unless modified?(file)
        task.update(read(file))
        recipes[file][:checksum] = checksum(file)
        task
      else
        debug("New task detected at #{file}. Attempting to load it now.")
        task = Task.new(read(file))
        recipes[file] = { checksum: checksum(file), id: task.id }
        overseer.add(task)
      end
    end

    def read(file)
      if file =~ /\.json$/i
        JSON.parse(File.read(file))
      else
        YAML.load_file(file)
      end.keys_to_sym
    end

    def exist?(file)
      recipes.include?(file)
    end

    def modified?(file)
      exist?(file) && checksum(file) != recipes[file][:checksum]
    end

    def checksum(file)
      Digest::MD5.file(file)
    end

    def delete(file)
      if paths.any? { |path| file.start_with?(path) }
        File.delete(file) if File.exist?(file)
      else
        raise RunTimeError, "The specified path does not exist within the paths that workbench is managing and will not be deleted: #{file}"
      end
      !File.exist?(file)
    end

    def remove(file)
      recipe = recipes.delete(file)
      return true unless recipe
      task = overseer.find(recipe[:id])
      return true unless task
      debug("Task #{task.id} is now being removed since the recipe file at #{file} is no longer there.")
      task.cancel
    end

    def load_recipes(path)
      BBLib.scan_files(path, '*.yml', '*.yaml', '*.json', recursive: recursive?) do |file|
        process(file)
        file
      end
    end

    protected

    def simple_setup
      require 'digest'
      self.interval = 60
    end

    def run(*args, &block)
      unless paths.empty?
        files = paths.flat_map { |path| load_recipes(path) }
        recipes.each do |file, _info|
          next if files.include?(file)
          remove(file)
        end
        debug("Workbench is now managing #{BBLib.plural_string(recipes.size, 'recipe')}.")
      else
        debug("No paths are currently configured in #{name}. Skipping iteration...")
        return false
      end
    end

  end
end
