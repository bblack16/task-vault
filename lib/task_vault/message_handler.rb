module TaskVault
  class MessageHandler
    include Runnable

    attr_int :counter, default: 0, serialize: false, protected_writer: true
    attr_ary_of Message, :queue, serialize: false, protected_writer: true
    attr_ary :event_keys, allow_nil: true, default: nil
    attr_element_of Message::SEVERITIES, :level, default: :trace

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

    def listen?(message)
      return false if message.level?(level)
      return true unless event_keys
      event_keys.any? do |event|
        [event].flatten(1).all? { |evt| message.event?(evt) }
      end
    end

    protected

    def simple_setup
      self.interval = 0.25
    end

    def process_message(message)
      puts message.content
    rescue => e
      error(e)
    end

    def run
      process_message(read) until queue.empty?
    rescue => e
      puts e, e.backtrace
    end
  end
end
