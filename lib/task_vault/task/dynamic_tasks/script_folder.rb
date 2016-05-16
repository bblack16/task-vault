class TaskVault

  class ScriptFolder < DynamicTask
    attr_reader :path, :filter, :scripts

    def path= path
      @path = path
    end

    def filter= filter
      @filter = filter.to_a
    end

    def generate_tasks
      BBLib.scan_files(@path, filter:@filter, recursive:@recursive).map do |script|
        task = Task.new(name:"#{@name}_#{script}", type: :script, cmd:script, working_dir:@working_dir, args:@args, weight:@weight, priority:@priority, max_life:@max_life, value_cap:@value_cap, repeat:@repeat, delay:@delay, message_handlers:@message_handlers)
        if @scripts.include?(script)
          if @scripts[script] != task.serialize
            @scripts[script] = task.serialize
            @parent.cancel task.name
            queue_msg("Script '#{script}' has been updated. The old version is being canceled...", severity: 5)
          else
            task = nil # Nothing is updated, ignore
          end
        else
          @scripts[script] = task.serialize
          queue_msg("Added a new script: #{script}", severity: 5)
        end
        task
      end
    end
    
    protected
    
      def custom_defaults
        @scripts = Hash.new
        super
        self.path = Dir.pwd
        self.filter = '*.rb'
      end

  end

end
