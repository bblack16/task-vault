

class TaskVault

  class MessageHandler < Component
    attr_reader :thread, :name, :started, :interval

    def name= name
      @name = name.to_s.to_clean_sym
    end

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def queue msg, **meta
      @queue.push meta.merge({msg:msg})
    end

    # Override the super call since it isn't needed here.
    def queue_msg msg, *args, **meta
      queue msg, **meta
    end

    def read_msg
      @queue.shift
    end

    # REIMPLEMENT THIS IN CHILD CLASSES
    def process_message
      # Reimpliment this is child classes. This is what reads from the queue and decides what to do with messages
      # In this parent class messages are simply printed to STDOUT usings puts
      msg = read_msg
      puts "#{msg[:time].strftime('%Y-%m-%d %H:%M:%S.%L')} - #{msg[:msg]}#{msg[:msg].is_a?(Exception) ? ': ' + msg[:msg].backtrace.join : ''}"
    end

    protected

      def init_thread
        @thread = Thread.new {
          begin
            loop do
              start = Time.now.to_f

              process_message while @queue.size > 0

              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            e
          end
        }
        @started = Time.now
      end

      def setup_defaults
        @queue = []
        self.name = :default
        self.interval = 0.5
      end

  end

end
