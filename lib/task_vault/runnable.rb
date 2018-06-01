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
      base.send(:attr_of, Object, :parent, default_proc: proc { TaskVault::Overseer.prototype }, allow_nil: true, default: nil, serialize: false)
      base.send(:attr_str, :id, default_proc: :generate_id)
      base.send(:attr_str, :name, default_proc: proc { |x| x.id })
      base.send(:attr_float_between, 0, nil, :interval, default: nil, allow_nil: true)
      base.send(:attr_hash, :metadata)
      base.send(:attr_of, Thread, :thread, default: nil, allow_nil: true, private_writer: true, serialize: false)
      base.send(:attr_of, MessageQueue, :message_queue, default_proc: proc { MessageQueue.new }, serialize: false)
      base.send(:attr_of, BBLib::TaskTimer, :timer, default_proc: proc { BBLib::TaskTimer.new }, serialize: false)
      base.send(:attr_time, :started, :stopped, default: nil, allow_nil: true, serialize: false)
    end

    def start
      return true if running?
      timer.start
      debug("#{self.class} (#{id}) is starting up...")
      init_thread
      running? && self.started = Time.now ? true : false
    end

    def stop
      return true if stopped?
      debug("Stopping #{self.class} (#{id}) now...")
      thread&.kill
      timer.stop
      sleep(0.1)
      stopped? && self.stopped = Time.now ? true : false
    end

    def restart
      stop && start
    end

    def running?
      thread && thread.alive?
    end

    def stopped?
      !running?
    end

    def uptime
      running? && started ? Time.now - started : 0
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
      debug("#{name} has finished running after #{(timer.current || timer.last).to_duration}.")
    end

    def process_failure
      # Hook to perform an action if the runnable item fails
    end

    def process_success
      # Hook to perform an action if the runnable item succeeds
    end

    def process_after
      # Hook to perform an action after the runnable item finishes (success or failure)
    end

    def init_thread(*args, &block)
      stop if running?
      self.thread = Thread.new do
        begin
          interval ? init_loop(*args, &block) : run(*args, &block)
          process_success
        rescue => e
          fatal(e)
          process_failure
        ensure
          timer.stop
          finished_run
          process_after
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
  end
end
