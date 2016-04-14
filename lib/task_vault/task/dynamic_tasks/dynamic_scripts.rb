class TaskVault

  class DynamicScripts < DynamicTask
    attr_reader :path, :filter
    attr_accessor :recursive
    attr_accessor :working_dir, :args, :weight, :priority,
                  :max_life, :value_cap, :repeat, :delay, :message_handlers

    def initialize name:nil, path:Dir.pwd, filter: '*', recursive: false, working_dir:nil, args:nil, weight:1, priority:3, max_life:nil, value_cap:1000000, repeat:1, delay:0, message_handlers: :default
      super(name)
      self.path = path
      self.filter = filter
      self.recursive = recursive
      self.working_dir = working_dir
      self.args = args
      self.weight = weight
      self.priority = priority
      self.max_life = max_life
      self.value_cap = value_cap
      self.repeat = repeat
      self.delay = delay
      self.message_handlers = message_handlers
    end

    def path= path
      @path = path
    end

    def filter= filter
      @filter = filter.to_a
    end

    def generate_tasks
      tasks = []
      BBLib.scan_files(@path, filter:@filter, recursive:@recursive).each do |script|
        tasks.push Task.new(name:"#{@name}_#{script}", type: :script, job:script, working_dir:@working_dir, args:@args, weight:@weight, priority:@priority, max_life:@max_life, value_cap:@value_cap, repeat:@repeat, delay:@delay, message_handlers:@message_handlers)
      end
      return tasks
    end

  end

end
