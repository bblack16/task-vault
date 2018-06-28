module TaskVault
  class Task
    include Runnable

    attr_float :weight, default: 1
    attr_int_between 0, nil, :priority, default: 10
    attr_int_between 0, nil, :run_limit, default: nil, allow_nil: true
    attr_float_between 0, nil, :timeout, :elevate_interval, default: nil, allow_nil: true
    attr_of [String, Integer, TrueClass, FalseClass, Range], :repeat, default: false, allow_nil: true
    attr_float :delay, default: nil, allow_nil: true
    attr_time :start_time, :stop_time, default: nil, allow_nil: true
    attr_element_of STATUSES.keys, :status, default: :created, serialize: false
    attr_int :run_count, default: 0, serialize: false, protected_writer: true
    attr_time :created, :queued, :added, :finished, :last_elevated, default: nil, allow_nil: true, serialize: false
    attr_int :initial_priority, default: nil, allow_nil: true, protected_writer: true, serialize: false
    attr_time :start_at, default: nil, allow_nil: true, serialize: false

    after :status=, :status_update
    after :start, :reset_start_at
    after :priority=, :set_initial_priority


    def create_task(opts = {}, &block)
      opts[:type] = :proc if block
      opts[:proc] = block if block
      Task.new(opts)
    end

    def message_queue
      if parent && parent != self
        parent.message_queue
      else
        super
      end
    end

    def start(*args, &block)
      super.tap do |result|
        if result
          self.status = :running
          self.run_count += 1
        end
      end
    end

    def name
      "#{id} (#{self.class})"
    end

    def cancel
      warn("Cancelling task #{name}...")
      self.status = :canceled
      stopped?
    end

    def timeout!
      warn("Task #{name} has timedout.")
      self.status = :timedout
      stopped?
    end

    def timeout?
      running? && timeout && Time.now - started > timeout
    end

    def finished?
      STATUSES[self.status][:queue] == :finished
    end

    def errored?
      [:errored, :timedout].any? { |status| status == self.status }
    end

    def rerun
      # TODO
    end

    def elevate
      self.last_elevated = Time.now
      self.priority = BBLib.keep_between(priority - 1, 0, 6)
    end

    def elevate?(interval = self.elevate_interval)
      return false unless interval
      Time.now >= (lasted_elevated || created) + interval
    end

    def update(*args, &block)
      _initialize(*args, &block)
    end

    def start_at
      return nil unless repeat || run_count.zero?
      return nil if status == :canceled
      return nil if stop_time && stop_time >= Time.now
      return nil if run_limit && run_limit <= run_count
      return start_time if start_time && run_count.zero?
      @start_at ||= calculate_start_at
    end

    def repeat?
      start_at ? true : false
    end

    def ready?
      start_at && Time.now >= start_at
    end

    protected

    def simple_setup
      self.parent = TaskVault::Overseer.prototype
    end

    def finished_run
      send(errored? ? :error : :debug, "#{name} has finished running after #{timer.last.to_duration}.")
      self.status = :finished unless STATUSES[self.status][:queue] == :finished
      reset_start_at
    end

    def reset_start_at
      self.start_at = nil
    end

    def status_update
      case status
      when :created
        self.created = Time.now
        debug("New task created: #{name}")
      when :queued
        self.queued = Time.now
        debug("Task #{name} is now queued.")
      when :running
        self.started = Time.now
        debug("Task #{name} is now running.")
      when :finished
        self.finished = Time.now
        self.priority = initial_priority
      when :errored, :canceled, :timedout
        self.finished = Time.now
        self.priority = initial_priority
        stop if running?
      else
        warn("Changed to unknown status for #{name}.")
      end
    end

    def calculate_start_at
      case repeat
      when TrueClass
        Time.now
      when FalseClass, NilClass
        run_count.zero? ? Time.now : (return nil)
      when Integer, Float
        repeat > run_count ? Time.now : (return nil)
      when Range
        Time.now + rand(repeat)
      when Time
        repeat
      else
        expression = repeat.to_s
        if expression =~ /^every/i
          run_count.positive? ? Time.at(started + repeat.parse_duration(output: :sec)) : Time.now
        elsif expression =~ /^after/i
          run_count.positive? ? Time.at(finished + repeat.parse_duration(output: :sec)) : Time.now
        elsif BBLib::Cron.valid?(expression)
          BBLib::Cron.next(expression, time: (run_count.positive? ? Time.now : created) || Time.now)
        else
          return nil
        end
      end + (delay || 0)
    end

    def set_initial_priority
      return if initial_priority
      self.initial_priority = priority
    end

  end
end
