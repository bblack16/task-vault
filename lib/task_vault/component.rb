class TaskVault

  # This is meant to be an abstract class that all the various TaskVault components inherit from to get boilerplate code out of the way
  class Component
    attr_reader :message_queue, :parent, :thread, :started, :stopped

    def initialize parent = nil, *args, **named
      self.parent = parent
      setup_defaults
      process_args(*args, **named)
      if named.include?(:start)
        init_thread if named.delete(:start)
      end
    end

    def start
      init_thread unless running?
      @started = Time.now
      queue_msg("DEBUG - Starting #{self.class}")
      running?
    end

    def stop
      queue_msg("DEBUG - Stopping #{self.class}")
      @stopped = Time.now
      @thread.kill if @thread
      sleep(0.3) # Need to wait for shutdown of thread before running is called. This is a possible race condition.
      !running?
    end

    def restart
      queue_msg("DEBUG - Restarting #{self.class}")
      stop
      start
    end

    def uptime
      return 0 if @started.nil?
      running? ? Time.now - @started : 0
    end

    def running?
      defined?(@thread) && @thread.alive?
    end

    def queue_msg msg, *handlers, **meta
      @message_queue = [] if !defined?(@message_queue)
      @message_queue.push({ msg:msg, handlers:handlers, meta:meta.merge({time: Time.now}) })
    end

    def read_msg
      @message_queue.shift
    end

    def has_msg?
      defined?(@message_queue) && @message_queue.size > 0
    end

    def parent= p
      @parent = p if p.is_a?(TaskVault)
    end

    # Should no longer be needed..leaving for now to be determined/deleted later
    # def set var, setting
    #   cmd = "#{var}=".to_sym
    #   if self.respond_to?(cmd)
    #     send(cmd, setting)
    #   else
    #     raise ArgumentError, "No setter method is availabe for '#{var}' on '#{self.class}'"
    #   end
    # end

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
            queue_msg("WARN - Unknown parameter passed to #{self.class}: #{k}. Ignoring...")
          end
        end
      end


  end

end
