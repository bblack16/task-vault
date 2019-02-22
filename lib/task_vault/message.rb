module TaskVault
  class Message
    include BBLib::Effortless

    SEVERITIES = [:unknown, :data, :trace, :debug, :info, :warn, :error, :fatal].freeze

    attr_of Object, :content, aliases: :message, arg_at: 0
    attr_of Object, :_source, default: nil, allow_nil: true, serialize: false
    attr_ary :event_key, aliases: [:event], default: [:default], pre_proc: proc { |*x| x.flatten.map { |s| s.to_s.to_sym } }
    attr_element_of SEVERITIES, :severity, default: :debug, pre_proc: proc { |x| SEVERITIES.include?(x.to_s.to_sym) ? x.to_s.to_sym : :unknown }
    attr_time :created

    def event?(expression)
      event.any? do |event|
        self.class.event?(event, expression)
      end
    end

    def level?(level)
      return false unless SEVERITIES.include?(level)
      SEVERITIES.index(level) >= SEVERITIES.index(severity)
    end

    def self.event?(key, expression)
      case expression
      when Regexp
        expression =~ key
      else
        key == expression.to_s.to_sym
      end
    end

    protected

    def simple_setup
      self.created = Time.now
    end

  end
end
