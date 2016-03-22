class TaskVault

  # This is meant to be an abstract class that all the various TaskVault components inherit from to get boilerplate code out of the way
  class Component
    attr_reader :message_queue, :parent, :thread

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
    end

    def stop
      @thread.kill if @thread
    end

    def restart
      stop
      start
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
          send(k,v)
        end
      end


  end

end
