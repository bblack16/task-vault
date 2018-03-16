require_relative 'message_queue'

module TaskVault
  module Runnable

    STATUSES = {
      created:  { sort: 0, queue: :queued },
      queued:   { sort: 1, queue: :queued },
      running:  { sort: 2, queue: :running },
      finished: { sort: 3, queue: :finished },
      errored:  { sort: 4, queue: :finished },
      timedout: { sort: 5, queue: :finished },
      canceled: { sort: 6, queue: :finished },
      unknown:  { sort: 99, queue: :finished }
    }

    def self.included(base)
      base.send(:include, BBLib::Effortless)
      base.send(:include, BBLib::TypeInit)
      base.send(:attr_of, Object, :parent, default_proc: proc { TaskVault::Overseer.prototype }, allow_nil: true, default: nil)
      base.send(:attr_str, :id, default_proc: :generate_id)
      base.send(:attr_str, :name, default_proc: proc { |x| "#{x.type}_#{x.id}"})
      base.send(:attr_float, :weight, default: 1)
      base.send(:attr_float_between, 0, nil, :interval, :timeout, :elevate_interval, default: nil, allow_nil: true)
      base.send(:attr_hash, :metadata)
      base.send(:attr_of, Thread, :thread, default: nil, allow_nil: true, private_writer: true, serialize: false)
      base.send(:attr_of, MessageQueue, :message_queue, default_proc: proc { MessageQueue.new }, serialize: false)
      base.send(:attr_of, BBLib::TaskTimer, :timer, default_proc: proc { BBLib::TaskTimer.new }, serialize: false)
      base.send(:attr_time, :started, :stopped, default: nil, allow_nil: true, serialize: false)

      base.send(:attr_int_between, 0, nil, :priority, default: 10)
      base.send(:attr_int_between, 0, nil, :run_limit, default: nil, allow_nil: true)
      base.send(:attr_of, [String, Integer, TrueClass, FalseClass, Range], :repeat, default: false, allow_nil: true)
      base.send(:attr_float, :delay, default: nil, allow_nil: true)
      base.send(:attr_time, :start_time, :stop_time, default: nil, allow_nil: true)
      base.send(:attr_element_of, STATUSES.keys, :status, default: :created, serialize: false)
      base.send(:attr_int, :run_count, default: 0, serialize: false, protected_writer: true)
      base.send(:attr_time, :created, :queued, :added, :finished, :last_elevated, default: nil, allow_nil: true)
      base.send(:attr_int, :initial_priority, default: nil, allow_nil: true, protected_writer: true, serialize: false)
    end

    def start
      return true if running?
      timer.start
      info("#{self.class} (#{id}) is starting up...")
      init_thread
      self.run_count += 1
      self.status = :running
      running? && self.started = Time.now ? true : false
    end

    def stop
      return true if stopped?
      info("Stopping #{self.class} (#{id}) now...")
      thread&.kill
      timer.stop
      sleep(0.1)
      stopped? && self.stopped = Time.now && self.status = :canceled ? true : false
    end

    alias cancel stop

    def restart
      stop && start
    end

    def timeout!
      info("Task #{name} has timedout.")
      self.status = :timedout
      stopped?
    end

    def timeout?
      running? && timeout && Time.now - started > timeout
    end

    def running?
      thread && thread.alive?
    end

    def stopped?
      !running?
    end

    def update(*args, &block)
      simple_init(*args, &block)
    end

    def finished?
      STATUSES[self.status][:queue] == :finished
    end

    def elevate
      self.last_elevated = Time.now
      self.priority = BBLib.keep_between(priority - 1, 0, 6)
    end

    def elevate?(interval = self.elevate_interval)
      return false unless interval
      Time.now >= (lasted_elevated || created) + interval
    end

    def uptime
      running? && started ? Time.now - started : 0
    end

    def start_at
      return nil unless repeat || run_count.zero?
      return nil if status == :canceled
      return nil if stop_time && stop_time >= Time.now
      return nil if run_limit && run_limit >= run_count
      return start_time if start_time
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
          BBLib::Cron.next(express, time: (run_count.positive? ? Time.now : created))
        else
          return nil
        end
      end + (delay || 0)
    end

    def repeat?
      start_at ? true : false
    end

    def ready?
      start_at && Time.now >= start_at
    end

    def register_to(parent)
      self.parent = parent
    end

    def unregister
      self.parent = nil
    end

    def queue_message(message, details = {})
      defaults = {
        severity: message.is_a?(Exception) ? :error : :info,
        event: :default,
        _source: self
      }
      message_queue.write(message, defaults.merge(queue_metadata).merge(details))
    end

    alias queue_msg queue_message

    [:data, :verbose, :debug, :info, :warn, :error, :fatal].each do |severity|
      define_method(severity) do |message, data = {}|
        queue_message(message, data.merge(severity: severity))
      end
    end

    def root
      return self unless parent
      return parent unless parent.respond_to?(:parent)
      parent.parent
    end

    def generate_id
      SecureRandom.uuid
    end

    protected

    def finished_run
      debug("Component #{self.class} has finished running.")
    end

    def init_thread(*args, &block)
      stop if running?
      self.thread = Thread.new do
        begin
          interval ? init_loop(*args, &block) : run(*args, &block)
          timer.stop
        rescue => e
          timer.stop
          fatal(e)
        ensure
          finished_run
        end
      end
    end

    def init_loop(*args, &block)
      debug("Starting up a loop for #{self.class}.")
      loop do
        timer.start(:loop)
        begin
          run(*args, &block)
        rescue => e
          error(e)
        ensure
          break unless interval
          sleep(calculate_sleep_time)
        end
      end
    end

    def run(*args, &block)
      raise AbstractError, 'The component base class does nothing. This should have been redefined!'
    end

    def queue_history(payload)
      history.pop until history.size <= (history_limit - 1)
      history.push(payload)
    end

    def calculate_sleep_time
      return 0 unless interval
      time = interval - timer.stop(:loop)
      time.negative? ? 0 : time
    end

    def queue_metadata
      {}
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
        debug("Task #{name} is now finished running after #{timer.last.to_duration}.")
      when :errored, :canceled, :timedout
        self.finished = Time.now
        self.priority = initial_priority
        warn("Task #{name} is now finished but was #{status} after #{timer.last.to_duration}.")
        stop if running?
      else
        warn("Changed to unknown status for #{name}.")
      end
    end
  end
end
