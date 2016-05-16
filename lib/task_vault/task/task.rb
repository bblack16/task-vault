require_relative 'task_template'

class TaskVault

  # Task exists soley as an abstract class and is essentially useless on its own.
  # CMDTask is the most basic full implementation of this class
  class Task < Component
    attr_reader :id, :name, :working_dir,
                :args, :weight, :priority, :templates,
                :max_life, :value_cap, :repeat, :delay, :start_at,
                :dependencies, :history, :history_limit, :run_limit,
                :initial_priority, :run_count, :status

    def run *args, **named
      pr = build_proc(*args, **named)
      if pr
        self.set_time :started, Time.now
        self.status = :running
        @run_count+= 1
      end
      @thread = Thread.new {
        begin
          add_history(pr.call(*args), status: :success)
        rescue StandardError, Exception => e
          queue_msg("Task #{@name} failed. Error message follows", severity: 2)
          queue_msg(e, severity: 2)
          add_history(e, status: :failure)
        end
      }
      return @thread.alive?
    end

    def name= n
      @name = n.to_s
    end

    def id= i
      @id = i.to_i
    end

    def args= a
      @args = (a.nil? ? [] : [a].flatten(1))
    end
    
    def templates= *t
      @templates = t.flatten
    end

    def working_dir= w
      @working_dir = w.nil? ? nil : (Dir.exists?(w) ? w : nil)
    end

    def value
      if @thread && !@thread.alive?
        @thread.value
      else
        nil
      end
    end
    
    def weight= w
      @weight = BBLib::keep_between(w.to_i, 0, nil)
    end

    def priority= n
      @priority = BBLib::keep_between(n.to_i, 0, 6)
      @initial_priority = @priority
    end

    def elevate
      @priority = BBLib::keep_between(@priority-1, 0, 6)
      set_time :last_elevated, Time.now
    end

    def status= s
      case s
      when :created
        set_time :created, Time.now
      when :queued
        set_time :queued, Time.now
      when :ready
        set_time :added, Time.now
        set_time :last_elevated, Time.now
      when :running
        set_time :started, Time.now
      when :finished || :error || :canceled || :timeout
        set_time :finished, Time.now
        @thread.kill if @thread.alive?
      end
      @status = STATES.include?(s) ? s : :unknown
    end

    def cancel
      @thread.kill if @thread
      self.status = :canceled
    end

    def max_life= n
      @max_life = n.nil? ? nil : BBLib::keep_between(n.to_i, 0, nil)
    end

    def value_cap= n
      @value_cap = BBLib::keep_between(n.to_i, 1, 1000000)
    end

    def history_limit= n
      @history_limit = BBLib::keep_between(n.to_i, 1, nil)
    end

    def repeat= r
      @repeat = r
      calc_start_time
    end

    def delay= n
      @delay = BBLib::keep_between((n.is_a?(Numeric) || n.nil? ? n.to_i : n.to_f - Time.now), 0, nil)
      calc_start_time
    end

    def start_at= s
      @start_at = s.is_a?(Time) ? s : Time.now
    end

    DEPENDENCY_TYPES = [
      :wait, # Wait until the dependency has run at least once since the last time this task ran
      :value, # Same as wait, but the value of the depency is passed in
      :prereq, # Similar to wait, but it only runs this task if the previous task succeeded.
      :prereq_value, # Same as prereq but also passed the value of the dependency.
      :on_finish, # Runs after the dependency has finished running with no repeats left.
      :on_finish_value,
      :on_fail, # Runs only if the dependency fails
      :on_fail_value,
      :on_success, # Same as on_finish but only executes if the previous task is finished, with no errors.
      :on_sucess_value
    ]

    def add_dependency *args, **dependencies
      dependencies.merge(args.last) if args.last.is_a?(Hash)
      dependencies.each do |task, type|
        if task.to_s =~ /\A\d+\z/
          task = task.to_s.to_i
        else
          task = task.to_s
        end
        @dependencies[task] = type if DEPENDENCY_TYPES.include?(type)
      end
    end

    def remove_dependency task
      @dependencies.delete task
    end

    def set_time type, time
      return nil unless @times.include?(type) && time.is_a?(Time)
      @times[type] = time
    end

    def method_missing sym, *args, **named
      if @times.include?(sym)
        return @times[sym]
      else
        super
      end
    end
    
    def started
      method_missing(:started)
    end

    STATES = {
      created: {},
      queued: {},
      ready: {},
      running: {},
      finished: {},
      error: {},
      waiting: {},
      failed_dependency: {},
      missing_dependency: {},
      timeout: {},
      canceled: {},
      unknown: {}
    }
    
    def save path = Dir.pwd, format = :yaml
      path = path.gsub('\\', '/')
      name = @name.to_s != '' ? @name : SecureRandom.hex(10);
      path = (path + '/' + name + '.' + format.to_s).pathify
      case format
      when :yaml
        serialize.to_yaml.to_file(path, mode: 'w')
      when :json
        serialize.to_json.to_file(path, mode: 'w')
      when :xml # Currenlty XML cannot be reserialized from
        serialize.to_xml.to_file(path, mode: 'w')
      end
      path
    end

    # Loads a task or dynamic task from either a path to a yaml or json file or from a hash
    def self.load path, templates = nil
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

      # Load templates
      unless templates.nil?
        if data.include?(:templates)
          [data[:templates]].flatten.each do |temp|
            tpath = "#{templates}/#{temp}.template".pathify
            puts temp, tpath, File.exists?(tpath)
            if File.exists?(tpath)
              data.deep_merge!(TaskTemplate.load(tpath).defaults)
            end
          end
        end
      end

      if data.include?(:class)
        task = Object.const_get(data.delete(:class).to_s).new(**data)
      else
        task = Task.new(**data)
      end
      raise "Failed to load task, invalid type '#{task.class}' is not inherited from TaskVault::Task" unless task.is_a?(Task)
      return task
    end
    
    def serialize
      values = BBLib.to_hash(self).merge({class: "#{self.class}"})
      values.hash_path_delete(*ignore_on_serialize)
      return values
    end
    
    protected
    
      def ignore_on_serialize
        [
          'initial_priority',
          'times',
          'thread',
          'value',
          'run_count',
          'id',
          'status',
          'start_at',
          'message_queue',
          'history'
        ]
      end
      
      def build_proc *args, **named
        # This method should generate and return a ruby proc
        proc{ |x| 'Do something?!?!' }
      end
    
      def init_thread
        run
      end
      
      def setup_defaults
        @times = {queued:nil, added:nil, started:nil, finished:nil, last_elevated:nil, created:nil}
        @run_count, @value, @thread = 0, nil, nil
        @dependencies, @history, @dependency_args = {}, [], []
        @templates = []
        self.id = nil
        self.name = SecureRandom.hex(10)
        self.working_dir = nil
        self.args = nil
        self.weight = 1
        self.priority = 3
        self.status = :created
        self.max_life = nil
        self.value_cap = 1000
        self.delay = 0
        self.repeat = 1
        self.message_handlers = :default
        self.history_limit = 10
        custom_defaults
      end
      
      def custom_defaults
        # Meant to be abstract
      end
      
      def process_args *args, **named
        # Handle arguments passed in to initialize
        if
          named.include?(:dependencies)
          named[:dependencies].each do |k, v|
            add_dependency(k => v)
          end
          named.delete(:dependencies)
        end
        super(*args, **named)
      end
      
      def add_history value, **other
        @history.push({value: value, time: Time.now, run_count: @run_count}.merge(**other))
        while @history.size > @history_limit
          @history.shift
        end
        value
      end
      
      def setup_args *args
        args.map{ |a| a.to_s.include?(' ') ? "\"#{a}\"" : a}.join(' ')
      end

      def calc_start_time
        dtime = Time.now + @delay
        self.start_at = dtime unless @repeat
        if @repeat.is_a?(String) && BBLib::Cron.valid?(@repeat)
          self.start_at = BBLib::Cron.next(@repeat, time:dtime)
        else
          self.start_at = dtime
        end
      end

  end

end
