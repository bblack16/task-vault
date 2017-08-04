# frozen_string_literal: true
module TaskVault
  class MessageHandler < SubComponent
    attr_symbol :name, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 0.25, serialize: true, always: true
    attr_int :counter, default: 0, serialize: false
    attr_reader :queue, serialize: false

    def push(msg)
      queue.push msg
    end

    def unshift(msg)
      queue.unshift msg
    end

    def self.load(data, parent: nil, namespace: Handlers)
      super
    end

    def describe
      super.merge(
        queue: queue.size,
        counter: counter,
        running: running?,
        uptime: uptime
      )
    end

    protected

    def setup_defaults
      @queue = []
      @counter = 0
    end

    # Needs to be redefined to avoid redirecting puts to the queue.
    def simple_init(*args)
      named = BBLib.named_args(*args)
      init_thread if named[:start]
    end

    def read
      self.counter += 1
      queue.shift
    end

    def read_all
      all = []
      queue.size.times do
        self.counter += 1
        all.push read_msg
      end
      all
    end

    def run
      queue_debug('Starting handler...')
      loop do
        start = Time.now.to_f
        process_message until queue.empty?
        sleep_time = interval - (Time.now.to_f - start)
        sleep(sleep_time.negative? ? 0 : sleep_time)
      end
    end

    # Reimplement this method in child classes.
    # It is called each interval until the queue is empty.
    def process_message
      # The following is just a very basic example that uses puts
      msg = read
      puts "#{msg[:time].strftime('%Y-%m-%d %H:%M:%S.%L')} - #{msg[:msg]}"
    end

    def setup_routes
      get '/queue' do
        queue
      end
    end
  end
end
