class TaskVault

  # This is meant to be an abstract class that all the various TaskVault components inherit from to get boilerplate code out of the way
  class Component
    attr_reader :message_queue, :parent, :thread, :started, :stopped, :message_handlers

    def initialize parent = nil, *args, **named
      self.parent = parent
      @message_handlers = [:default]
      setup_defaults
      process_args(*args, **named)
      if named.include?(:start)
        init_thread if named.delete(:start)
      end
    end

    def start
      init_thread unless running?
      @started = Time.now
      queue_msg("Starting #{self.class}", severity: 5)
      running?
    end

    def stop
      queue_msg("Stopping #{self.class}", severity: 5)
      @stopped = Time.now
      @thread.kill if @thread
      sleep(0.3) # Need to wait for shutdown of thread before running is called. This is a possible race condition.
      !running?
    end

    def restart
      queue_msg("Restarting #{self.class}", severity: 5)
      stop
      start
    end

    def uptime
      return 0 if @started.nil?
      running? ? Time.now - @started : 0
    end

    def running?
      defined?(@thread) && !@thread.nil? && @thread.alive?
    end

    def message_handlers= handlers
      @message_handlers = [handlers].flatten
    end

    def queue_msg msg, **meta
      @message_queue = [] if !defined?(@message_queue)
      @message_queue.push({ msg:msg, handlers:@message_handlers, meta:meta.merge({time: Time.now, component: self.class.to_s}) })
    end

    def read_msg
      @message_queue.shift
    end

    def has_msg?
      defined?(@message_queue) && @message_queue.size > 0
    end

    def parent= p
      @parent = p
    end

    protected

      def init_thread
        # place code here to start @thread as a thread
      end

      def setup_defaults
        # For use in child classes
      end

      def process_args *args, **named
        # Handle arumgents passed in to initialize
        named.each do |k,v|
          if respond_to?("#{k}=".to_sym)
            send("#{k}=".to_sym, v)
          else
            queue_msg("Unknown parameter passed to #{self.class}: #{k}. Ignoring...", severity: 8)
          end
        end
      end


  end

end
