module TaskVault
  class MessageHandler
    include Runnable
    attr_int :counter, default: 0, serialize: false, protected_writer: true
    attr_ary :queue, serialize: false, protected_writer: true

    def push(message)
      queue.push(message)
    end

    def add(*messages)
      messages.map { |message| push(message) }
    end

    def read
      return nil if queue.empty?
      self.counter += 1
      queue.shift
    end

    def read_all
      queue.size.times.map { read }
    end

    protected

    def simple_setup
      self.interval = 0.25
    end

    def process_message(message)
      puts message[:message]
    rescue => e
      error(e)
    end

    def run
      process_message(read) until queue.empty?
    end
  end
end
