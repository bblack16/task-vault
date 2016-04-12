require 'securerandom'

class TaskVault

  class Task < BaseTask
    attr_reader :id, :name, :type, :working_dir, :interpreter,
                :job, :args, :weight, :priority, :message_handlers,
                :max_life, :value_cap, :repeat, :delay, :start_at,
                :couriers, :thread, :dependencies, :events,
                :initial_priority, :run_count, :status

    TYPES = [
      :proc, :cmd, :script, :ruby, :eval  #, :eval_proc
    ]

    def run interpreter_path = @interpreter
      pr = build_proc interpreter_path
      if pr
        self.set_time :started, Time.now
        self.status = :running
        @run_count+= 1
      end
      @thread = Thread.new {
        begin
          pr.call(args)
        rescue StandardError, Exception => e
          queue_msg("Task #{@name} failed. Error message follows")
          queue_msg(e)
          e
        end
      }
      return @thread.alive?
    end

    def name= n
      @name = n.to_s
    end

    def type= t
      @type = TYPES.include?(t.to_sym) ? t.to_sym : nil
    end

    def id= i
      @id = i.to_i
    end

    def job= pr
      @job = pr
    end

    def interpreter= i
      @interpreter = i
    end

    def working_dir= w
      @working_dir = w.nil? ? nil : (Dir.exists?(w) ? w : nil)
    end

    def thread= t
      @thread = t
    end

    def value
      if @thread && !@thread.alive? then @thread.value else nil end
    end

    def args= a
      @args = a.nil? ? [] : [a].flatten(1)
    end

    def args
      # if defined?(@proc) && @proc.parameters.map{ |t, v| v }.include?(:mh)
      #   @args + @dargs + [{mh: @message_handler, value_cap: @value_cap}]
      # else
      #
      # end
      @args + @dargs
    end

    def weight= w
      @weight = BBLib::keep_between(w.to_i, 0, nil)
    end

    def priority= n, init = true
      @priority = BBLib::keep_between(n.to_i, 0, 6)
      @initial_priority = @priority if init
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
      when :finished, :error, :failed_dependency, :canceled, :timeout
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

    def message_handlers= mh
      @message_handlers = [mh].flatten
    end

    def add_dependency name, type: :wait
      @dependencies[name] = Overseer::DEPEND_TYPES.include?(type) ? type : :wait
    end

    def remove_dependency name
      @dependencies.delete name
    end

    def set_time type, time
      return nil unless @times.include?(type) && time.is_a?(Time)
      @times[type] = time
    end

    def method_missing args
      if @times.include?(args)
        return @times[args]
      else
        super(args)
      end
    end

    def serialize
      values = BBLib.to_hash(self)
      values.hash_path_delete 'initial_priority', 'dargs', 'times', 'thread', 'value', 'run_count', 'id', 'status', 'start_at', 'message_handler', 'proc'
      return values
    end

    def save path = Dir.pwd, format = :yaml
      path = path.gsub('\\', '/')
      name = @name.to_s != '' ? @name : SecureRandom.hex(10);
      path = (!path.end_with?('/') ? path + '/' : '') + name + '.' + format.to_s
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

    protected

      def init_thread
        run
      end

      def setup_defaults
        @times = {queued:nil, added:nil, started:nil, finished:nil, last_elevated:nil, created:nil}
        @run_count, @value, @thread = 0, nil, nil
        @dependencies = {}
        @dargs = []
        self.type = :proc
        self.id = nil
        self.name = SecureRandom.hex(10)
        self.job = nil
        self.interpreter = nil
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
      end

      def process_args *args, **named
        # Handle arumgents passed in to initialize
        if named.include?(:dependencies) then named[:dependencies].each{ |k, v| add_dependency(k, type: v)}; named.delete(:dependencies) end
        super(*args, **named)
      end

      def build_proc interpreter_path
        @proc = nil
        case @type
        when :proc
          @proc = @job.is_a?(Proc) ? @job : nil
        when :cmd
          @proc = cmd_proc(@job)
        when :script
          @proc = cmd_proc("#{interpreter_path} #{@job}")
        when :ruby
          @proc = cmd_proc("#{Gem.ruby} #{@job}")
        when :eval
          @proc = eval_proc(@job)
        # when :eval_proc
        #   ev = eval(@job)
        #   if ev.is_a?(Proc)
        #     @proc = ev
        #   end
        end
        @proc
      end

      def cmd_proc cmd
        proc{ |*args|
          results = []
          process = IO.popen("#{cmd} #{args.map{ |a| a.to_s.include?(' ') ? "\"#{a}\"" : a}.join(' ') }")
          while !process.eof?
            line = process.readline
            queue_msg(line, *@message_handlers, task_name: @name, task_id: @id)
            results.push line
            if @value_cap
              results.shift until results.size <= @value_cap
            end
          end
          process.close
          results
        }
      end

      def eval_proc eval
        proc{ |*args|
          results = []
          process = IO.popen("#{Gem.ruby} -e \"#{eval.gsub("\"", "\\\"")}\"")
          while !process.eof?
            line = process.readline
            queue_msg(line, *@message_handlers, task_name: @name, task_id: @id)
            results.push line
            if @value_cap
              results.shift until results.size <= @value_cap
            end
          end
          process.close
          results
        }
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
