module TaskVault

  class MessageHandler < Component
    attr_symbol :name, default: :message_handler
    attr_float_between 0.001, nil, :interval, default: 0.25
    attr_reader :queue

    def push msg
      @queue.push msg
    end

    def unshift msg
      @queue.unshift msg
    end

    protected

      def setup_defaults
        @queue = Array.new
        setup_serialize
      end

      # Needs to be redefined to avoid redirecting puts to the queue.
      def custom_lazy_init *args
        named = BBLib.named_args(*args)
        init_thread if named[:start]
      end

      def read
        @queue.shift
      end

      def read_all
        all = []
        @queue.size.times do
          all.push read_msg
        end
        all
      end

      def run
        loop do
          start = Time.now.to_f
          process_message until @queue.empty?
          sleep_time = @interval - (Time.now.to_f - start)
          sleep(sleep_time < 0 ? 0 : sleep_time)
        end
      end

      # Reimplement this method in child classes.
      # It is called each interval until the queue is empty.
      def process_message
        # The following is just a very basic example that uses puts
        msg = read
        puts "#{msg[:time].strftime('%Y-%m-%d %H:%M:%S.%L')} - #{msg[:msg]}"
      end

      def setup_serialize
        serialize_method :name, always: true
        serialize_method :interval, always: true
      end
  end

end
