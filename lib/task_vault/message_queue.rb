require_relative 'message'

module TaskVault
  class MessageQueue < BBLib::HashStruct
    include BBLib::Effortless

    attr_ary_of Message, :queue, :history, default: [], private_writer: true
    attr_int_between 0, nil, :limit, default: 100_000
    attr_int_between 0, nil, :history_limit, default: 100
    attr_int :written_messages, :read_messages, :dropped_messages, default: 0, serialize: false

    def write(message, details = {})
      message = Message.new(details.merge(message: message)) unless message.is_a?(Message)
      write_history(message)
      self.written_messages += 1
      queue.push(message).tap { |x| clean_queue }
    rescue => e
      queue.push({ message: e, severity: :fatal })
    end

    def read_first
      self.read_messages += 1
      queue.shift
    end

    def read_last
      self.read_messages += 1
      queue.pop
    end

    def read(count = nil)
      return read_first unless count
      case count
      when Integer
        count.times.map { read_first }
      else
        raise TypeError, "Expected count to be an Integer or NilClass, got a #{count.class}"
      end
    end

    def read_all
      read(queue.size)
    end

    def empty?
      queue.empty?
    end

    def message?
      !empty?
    end

    def size
      queue.size
    end

    protected

    def write_history(payload)
      history.push(payload).tap do |_payload|
        clean_history
      end
    end

    def clean_queue
      until queue.size <= limit
        self.dropped_messages += 1
        queue.shift
      end
    end

    def clean_history
      history.shift until history.size <= history_limit
    end

  end
end
