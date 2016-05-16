class TaskVault

  class DynamicScripts < DynamicTask
    attr_reader :path, :filter
    attr_accessor :recursive, :working_dir, :args, :weight, :priority,
                  :max_life, :value_cap, :repeat, :delay, :message_handlers

    def path= path
      @path = path
    end

    def filter= filter
      @filter = filter.to_a
    end

    def generate_tasks
      BBLib.scan_files(@path, filter:@filter, recursive:@recursive).map do |script|
        Task.new(name:"#{@name}_#{script}", type: :script, cmd:script, working_dir:@working_dir, args:@args, weight:@weight, priority:@priority, max_life:@max_life, value_cap:@value_cap, repeat:@repeat, delay:@delay, message_handlers:@message_handlers)
      end
    end
    
    protected
    
      def setup_defaults
        super
        self.path = Dir.pwd
        self.filter = '*'
        self.recursive = false
        self.working_dir = nil
        self.args = nil
        self.weight = 1
        self.priority = 3
        self.max_life = nil
        self.value_cap = 1000000
        self.repeat = 1
        self.delay = 0
        self.message_handlers = :default
      end

  end

end
