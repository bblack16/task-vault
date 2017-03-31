# frozen_string_literal: true
module TaskVault
  class Task < SubComponent
    STATES = [
      :created, :queued, :ready, :running, :finished, :error, :waiting,
      :canceled, :timedout, :unknown
    ].freeze

    after :set_initial_priority, :priority=
    after :status_change, :status=
    after :calculate_start_time, :delay=, :repeat=

    attr_int :id
    attr_string :name, default: '', serialize: true, always: true
    attr_float :delay, allow_nil: true, default: 0, serialize: true, always: true
    attr_time :start_at, fallback: Time.now
    attr_float_between 0, nil, :weight, default: 1, serialize: true, always: true
    attr_int_between 0, nil, :run_limit, default: nil, allow_nil: true, serialize: true, always: true
    attr_int_between 0, 6, :priority, default: 3, serialize: true, always: true
    attr_float_between 0, nil, :timeout, allow_nil: true, default: nil, serialize: true, always: true
    attr_element_of STATES, :status, default: :created, fallback: :unknown
    attr_of [String, Fixnum, TrueClass, FalseClass], :repeat, serialize: true, always: true
    attr_int_between 1, nil, :elevate_interval, default: nil, allow_nil: true, serialize: true, always: true
    attr_reader :run_count, :initial_priority, :timer, :times

    def stop
      @timer.stop if @timer.active?
      super
    end

    def cancel
      queue_msg('Cancel has been called. Task should end shortly.', severity: :info)
      self.status = :canceled
      !running?
    end

    def rerun
      return false if parent.nil? || [:created, :queued, :running, :ready, :waiting].any? { |s| s == status }
      queue_msg('Rerun has been called. Task should begin to run again now.', severity: :info)
      @priority = @initial_priority
      @run_limit += 1 if @run_limit
      @parent.rerun(id)
      true
    end

    def elevate
      @priority = BBLib.keep_between(@priority - 1, 0, 6)
      set_time :last_elevated
    end

    def elevate_check(parent_interval = nil)
      interval = @elevate_interval || parent_interval
      return unless interval
      elevate if Time.now >= ((last_elevated || created) + interval)
    end

    def set_time(type, time = Time.now)
      return nil unless @times.include?(type) && time.is_a?(Time)
      @times[type] = time
    end

    def reload(args)
      _lazy_init(args)
    end

    def details(*attributes)
      attributes.map do |a|
        [a, (respond_to?(a.to_sym) ? send(a.to_sym) : nil)]
      end.to_h
    end

    def calculate_start_time
      return false if status == :canceled
      rpt = true
      self.start_at = Time.now + @delay if run_count.zero?
      if @repeat.nil? || @repeat == false || run_limit && run_limit.positive? && run_count >= run_limit || @repeat.is_a?(Numeric) && @repeat <= @run_count
        rpt = false
      elsif @repeat == true
        self.start_at = Time.now
      elsif @repeat.is_a?(String)
        if @repeat.start_with?('every') && run_count.positive?
          self.start_at = Time.at(started + @repeat.parse_duration(output: :sec))
        elsif @repeat.start_with?('after') && run_count.positive?
          self.start_at = Time.at(Time.now + @repeat.parse_duration(output: :sec))
        elsif BBLib::Cron.valid?(@repeat)
          self.start_at = BBLib::Cron.next(@repeat, time: (run_count.positive? ? Time.now : start_at))
        end
      end
      rpt
    end

    def timeout_check
      if running? && @timeout && Time.now - started > timeout
        self.status = :timed_out
        true
      else
        false
      end
    end

    def stats
      @timer.stats :default
    end

    def save(path = Dir.pwd, format: :yml)
      super(path, format: format, name: @name)
    end

    def method_missing(*args)
      if @times.include?(args.first)
        @times[args.first]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @times.include?(method) || super
    end

    def self.load(data, parent: nil, namespace: Tasks)
      super
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
        created:       Time.now
      }
      @run_count        = 0
      @initial_priority = 3
      @timer            = BBLib::TaskTimer.new
      self.delay        = 0
      self.repeat       = 1
    end

    def init_thread
      @thread = Thread.new do
        begin
          @timer.start
          run
          @timer.stop
          self.status = :finished
        rescue => e
          @timer.stop
          self.status = :error
          queue_msg e
        end
      end
      self.status = :running
      @run_count += 1
    end

    def hide_on_inspect
      super + [:@history]
    end

    def add_history(value, **other)
      @history.push({ value: value, time: Time.now, run_count: @run_count }.merge(**other))
      @history.shift while @history.size > @history_limit
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
  end
end
