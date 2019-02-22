module TaskVault
  class Task
    include Runnable

    # -------------
    # Task Settings
    # -------------
    # Sets the global weight for this task. By default the task runner can only run
    # a set amount of weight at a time.
    attr_float :weight, default: 1
    # Sets the priority of the task. The lower the number the higher the priority.
    # Priority zero means run immediately, ignoring weight limits.
    attr_int_between 0, nil, :priority, default: 10
    # The max number of times this job can execute. nil means there is no limit.
    attr_int_between 0, nil, :run_limit, default: nil, allow_nil: true
    # How long this task will be allowed to execute before it is killed.
    attr_float_between 0, nil, :timeout, :elevate_interval, default: nil, allow_nil: true
    # If, how and when this task will repeat. Can be a count, a cron, a time based interval,
    # a range (random number of times), true or false. True means repeat forever, false
    # means never repeat.
    attr_of [String, Integer, TrueClass, FalseClass, Range], :repeat, default: false, allow_nil: true
    # The number of seconds to wait before this task is executed.
    attr_float :delay, default: nil, allow_nil: true
    # Preset times to run this task or to stop it if it is still running. nil
    # disables the behavior.
    attr_time :start_time, :stop_time, default: nil, allow_nil: true
    # A unique or random key used to determine when or when not to run this
    # task if any other tasks with the same key are being run. Setting this to
    # nil means the task can be run concurrently.
    attr_str :concurrency_key, default: nil, allow_nil: true
    # The number of concurrent instances of this task or any tasks with the same
    # concurrency key can be run within a given Overseer.
    attr_int :concurrency_cap, default: 1

    # --------------------------------
    # Attribute storage (non-settings)
    # --------------------------------
    # The current status of the task.
    attr_element_of STATUSES.keys, :status, default: :created, serialize: false
    # The number of times the task has been run (success or failure)
    attr_int :run_count, default: 0, serialize: false, protected_writer: true
    # Times for specific events related to this task.
    attr_time :created, :queued, :added, :finished, :last_elevated, default: nil, allow_nil: true, serialize: false
    # The priority this task started with prior to an elevations.
    attr_int :initial_priority, default: nil, allow_nil: true, protected_writer: true, serialize: false
    # The calculated time the task will next start at (when a slot is available)
    attr_time :start_at, default: nil, allow_nil: true, serialize: false

    after :status=, :status_update
    after :start, :reset_start_at
    after :priority=, :set_initial_priority

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

    # Immediately stops the running task and places it into the canceled state.
    # For timeouts use timeout! instead.
    def cancel
      warn("Cancelling task #{name}...")
      self.status = :canceled
      stopped?
    end

    # When called this task will be killed and set to a state of timed out. Use
    # cancel! for non timeout related kills.
    def timeout!
      warn("Task #{name} has timedout.")
      self.status = :timedout
      stopped?
    end

    # Holds the current tread until this task finishes or a timeout is reached.
    # Will return true if the job finished, false if the time runs out first.
    def wait!(timeout = nil, sleep_interval = 0.1)
      start = Time.now.to_f
      sleep(sleep_interval) until finished? || timeout && Time.now.to_f - start > timeout
      timeout ? (Time.now.to_f - start > timeout) : true
    end

    # Returns true if this task should be timedout.
    def timeout?
      running? && timeout && Time.now - started > timeout
    end

    # Returns true if this task is currently in one of the finished states.
    def finished?
      STATUSES[self.status][:queue] == :finished
    end

    # Similar to finished but only returns true if the task will also no longer
    # repeat again.
    def completed?
      finished? && !repeat?
    end

    # Returns true if this task is in any errored state.
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
      if stop_time && stop_time <= Time.now
        self.status = :finished
        return nil
      end
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
