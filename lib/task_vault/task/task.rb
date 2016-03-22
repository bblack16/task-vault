class TaskVault

  class Task
    include BBLib
    attr_reader :id, :name, :type, :working_dir, :interpreter,
                :job, :args, :weight, :priority,
                :max_life, :value_cap, :repeat, :delay, :start_at,
                :couriers, :thread, :dependencies, :events,
                :initial_priority, :run_count, :status

    def initialize name:nil, interpreter:nil, working_dir:nil, dependencies:nil, id:nil, type:nil, job:nil, args:nil, weight:1, priority:3, max_life:nil, value_cap:10000, repeat:1, delay:0, message_handler_name:nil
      init
      @dargs = []
      self.type = type
      self.id = id
      self.name = name.nil? ? id : name
      self.job = job
      self.interpreter = interpreter
      self.working_dir = working_dir
      self.args = args
      self.weight = weight
      self.priority = priority
      self.status = :created
      self.max_life = max_life
      self.value_cap = value_cap
      self.delay = delay
      self.repeat = repeat
      self.message_handler_name = message_handler_name
      if dependencies then dependencies.each{ |k, v| add_dependency(k, type: v)} end
    end

    TYPES = [
      :proc, :cmd, :script, :ruby, :eval, :eval_proc
    ]

    def run
      pr = build_proc
      if pr
        self.set_time :started, Time.now
        self.status = :running
        @run_count+= 1
      end
      @thread = Thread.new {
        begin
          pr.call(args)
        rescue StandardError, Exception => e
          e
        end
      }
      return @thread.alive?
    end

    def name= n
      @name = n.to_s
    end

    def type= t
      @type = TYPES.include?(t) ? t : nil
    end

    def id= i
      @id = i.to_i
    end

    def job= pr
      @job = pr
    end

    def interpreter= i
      @interpreter = i.nil? ? nil : (File.exists?(i) ? i : nil)
    end

    def working_dir= w
      @working_dir = w.nil? ? nil : (Dir.exists?(w) ? w : nil)
    end

    def thread= t
      @thread = t
    end

    def value
      if @thread then @thread.value else nil end
    end

    def args= a
      @args = a.nil? ? [] : [a].flatten(1)
    end

    def args
      if defined?(@proc) && @proc.parameters.map{ |t, v| v }.include?(:mh)
        @args + @dargs + [{mh: @message_handler, value_cap: @value_cap}]
      else
        @args + @dargs
      end
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

    def message_handler_name= mh
      @message_handler_name = [mh].flatten
    end

    def message_handler= mh
      @message_handler = mh.is_a?(MessageHandler) || mh.is_a?(Array) && !mh.any?{ |m| !m.is_a?(MessageHandler)} ? [mh].flatten : nil
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
      end
    end

    def serialize
      values = BBLib.to_hash(self)
      values.hash_path_delete 'initial_priority', 'dargs', 'times', 'thread', 'value', 'run_count', 'id', 'status', 'start_at', 'message_handler', 'proc'
      values.keys_to_s
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

      def init
        @times = {queued:nil, added:nil, started:nil, finished:nil, last_elevated:nil, created:nil}
        @run_count, @value, @thread = 0, nil, nil
        @dependencies = {}
      end

      def build_proc
        @proc = nil
        case @type
        when :proc
          @proc = @job.is_a?(Proc) ? @job : nil
        when :cmd
          @proc = cmd_proc(@job)
        when :script
          @proc = cmd_proc("#{@interpreter} #{@job}")
        when :ruby
          @proc = cmd_proc("#{Gem.ruby} #{@job}")
        when :eval
          @proc = eval_proc(@job)
        when :eval_proc
          ev = eval(@job)
          if ev.is_a?(Proc)
            @proc = ev
          end
        end
        @proc
      end

      def cmd_proc cmd
        proc{ |*args, mh:nil, value_cap:nil|
          results = []
          process = IO.popen("#{cmd} #{args.map{ |a| a.to_s.include?(' ') ? "\"#{a}\"" : a}.join(' ') }")
          while !process.eof?
            line = process.readline
            if defined?(mh) && mh.is_a?(Array)
              mh.each do |h|
                h.push line if h.is_a?(MessageHandler)
              end
            else
              puts "Message handler FAIL"
            end
            results.push line
            if value_cap
              results.shift until results.size <= value_cap
            end
          end
          process.close
          results
        }
      end

      def eval_proc eval
        proc{ |*args, mh:nil, value_cap:nil|
          begin
            eval(eval)
          rescue StandardError, Exception => e
            e
          end
        }
      end

      def calc_start_time
        dtime = Time.now + @delay
        self.start_at = dtime unless @repeat
        if @repeat.is_a?(String) && Cron.valid?(@repeat)
          self.start_at = Cron.next(@repeat, time:dtime)
        else
          self.start_at = dtime
        end
      end

  end

end
