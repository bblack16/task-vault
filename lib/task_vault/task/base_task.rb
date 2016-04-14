
class TaskVault

  class BaseTask < Component

      # 'Base Task exists soley for Tasks and DynamicTasks to share a base type and as such is abstract.'

      # Loads a task or dynamic task from either a path toa  yaml or json file or from a hash
      def self.load path
        data = (path.is_a?(Hash) ? path : Hash.new)
        if path.is_a?(String)
          if path.end_with?('.yaml') || path.end_with?('.yml')
            data = YAML.load_file(path)
          elsif path.end_with?('.json')
            data = JSON.parse(File.read(path))
          else
            raise "Failed to load task from '#{path}'. Invalid file type. Must be yaml or json."
          end
        end
        data.keys_to_sym!
        if data.include?(:class)
          task = Object.const_get(data.delete(:class).to_s).new(**data)
        else
          task = Task.new(**data)
        end
        raise "Failed to load task, invalid type '#{task.class}' is not inherited from TaskVault::BaseTask" unless task.is_a?(BaseTask)
        return task
      end

  end

end
