module TaskVault

  class Task < Component

    STATES = [
      :created, :queued, :ready, :running, :finished, :error, :waiting,
      :failed_dependency, :missing_dependency, :canceled, :timedout, :unknown
    ]

    after :set_initial_priority, :priority=
    after :status_change, :status=
    after :calculate_start_time, :delay=, :repeat=

    attr_int :id
    attr_string :name, default: ''
    attr_valid_dir :working_dir, allow_nil: true, default: nil
    attr_float :delay, allow_nil: true, default: 0
    attr_time :start_at, fallback: Time.now
    attr_float_between 0, nil, :weight, default: 1
    attr_int_between 0, nil, :run_limit, default: nil, allow_nil: true
    attr_int_between 0, 6, :priority, default: 3
    attr_float_between 0, nil, :timeout, allow_nil: true, default: nil
    attr_element_of STATES, :status, default: :created, fallback: :unknown
    attr_accessor :repeat
    attr_reader :run_count, :initial_priority, :timer

    def cancel
      self.status = :canceled
      return running?
    end

    def elevate
      @priority = BBLib::keep_between(@priority - 1, 0, 6)
      set_time :last_elevated
    end

    def set_time type, time = Time.now
      return nil unless @times.include?(type) && time.is_a?(Time)
      @times[type] = time
    end

    def reload args
      _lazy_init(args)
    end

    def details *attributes
      attributes.map do |a|
        [a, (self.respond_to?(a.to_sym) ? self.send(a.to_sym) : nil)]
      end.to_h
    end

    def calculate_start_time
      return false if status == :canceled
      rpt = true
      self.start_at = Time.now + @delay if run_count == 0
      if @repeat.nil? || @repeat == false || run_limit && run_limit > 0 && run_count >= run_limit || @repeat.is_a?(Numeric) && @repeat <= @run_count
        rpt = false
      elsif @repeat == true
        self.start_at = Time.now
      elsif @repeat.is_a?(String)
        if @repeat.start_with?('every') && run_count > 0
          self.start_at = Time.at(self.started + @repeat.parse_duration(output: :sec))
        elsif @repeat.start_with?('after') && run_count > 0
          self.start_at = Time.at(Time.now + @repeat.parse_duration(output: :sec))
        elsif BBLib::Cron.valid?(@repeat)
          self.start_at = BBLib::Cron.next(@repeat, time: (run_count > 0 ? Time.now : self.start_at))
        end
      end
      rpt
    end

    def timeout_check
      if running? && @max_life && Time.now - self.started > max_life
        self.status = :timed_out
        true
      else
        false
      end
    end

    def stats
      @timer.stats :default
    end

    def save path = Dir.pwd, format: :yml
      super(path, format: format, name: @name)
    end

    def method_missing *args
      if @times.include?(args.first)
        @times[args.first]
      else
        super
      end
    end

    protected

      def lazy_setup
        super
        @times = {
          queued:        nil,
          added:         nil,
          started:       nil,
          finished:      nil,
          last_elevated: nil,
          created:       nil
        }
        @run_count        = 0
        @initial_priority = 3
        @timer            = BBLib::TaskTimer.new
        self.delay        = 0
        self.repeat       = 1
        setup_serialize
      end

      def init_thread
        @thread = Thread.new{
          begin
            @timer.start
            run
            @timer.stop
            self.status = :finished
          rescue Exception => e
            self.status = :error
            queue_msg e
          end
        }
        self.status = :running
        @run_count += 1
      end

      def hide_on_inspect
        super + [:@history]
      end

      def add_history value, **other
        @history.push({value: value, time: Time.now, run_count: @run_count}.merge(**other))
        while @history.size > @history_limit
          @history.shift
        end
        value
      end

      def msg_metadata
        {
          id:        @id,
          name:      @name,
          status:    @status,
          run_count: @run_count
        }
      end

      def set_initial_priority
        @initial_priority = @priority
      end

      def status_change
        case @status
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
          stop
        end
      end

      def setup_serialize
        serialize_method :name, always: true
        serialize_method :repeat, always: true
        serialize_method :run_limit, always: true
        serialize_method :timeout, always: true
        serialize_method :delay, always: true
        serialize_method :priority, :initial_priority, always: true
        serialize_method :weight, always: true
        serialize_method :history_limit, always: true
        serialize_method :working_dir, always: true
        super
      end

  end

end
