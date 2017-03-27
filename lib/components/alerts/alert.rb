require_relative 'operators'

module TaskVault
  class Component < BBLib::LazyClass; end

  class Alert < BBLib::LazyClass

    SEVERITIES = [:clear, :info, :warn, :minor, :major, :critical]

    OPERATORS = {
      eq:  'equal to',
      gt:  'greater than',
      gte: 'greater than or equal to',
      lt:  'less than',
      lte: 'less than or equal to',
      not: 'not equal to'
    }

    def self.operators
      @operators ||= (TaskVault::Operators.methods - Object.methods)
    end

    attr_of TaskVault::Component, :parent, default: nil, allow_nil: true
    attr_str :name, default: nil, allow_nil: true, serialize: true
    attr_str :message, default: '{{name}} is {{operator}} {{threshold}} on {{hostname}} (Currently: {{value}})', serialize: true
    attr_of Object, :info, :warn, :minor, :major, :critical, default: nil, allow_nil: true, serialize: true
    attr_element_of operators, :operator, default: :eq, serialize: true, always: true
    attr_bool :invert, default: false, serialize: true
    attr_str :target, default: '', serialize: true, always: true
    attr_hash :metadata, default: {}, serialize: true
    attr_sym :custom_event_key, default: nil, allow_nil: true, serialize: true
    attr_str :custom_description, default: nil, allow_nil: true, serialize: true
    attr_ary_of Symbol, :events, default: nil, allow_nil: true, serialize: true
    attr_int_between 0, nil, :round, default: 2, allow_nil: true, serialize: true
    attr_of Time, :last_triggered, default: nil, allow_nil: true
    attr_int :triggered_count, default: 0

    # Redefine this in subclasses
    def describe
      return custom_description if custom_description
      "Checks '#{target}' from messages out of #{parent&.name || 'parent'}." +
      " If the value #{(invert? ? Operators::INVERTED_TRANSLATIONS : Operators::TRANSLATIONS)[operator] || operator} " +
      "#{thresholds.map { |s, t| "#{t} (#{s})" if t }.compact.join(', ')} an alert is sent." +
      (events ? " Only checks events of type#{events.size == 1 ? '' : 's'} #{events.join(', ')}." : '')
    end

    def event_key(details = {})
      (custom_event_key || "#{name}_#{target}_#{hostname}").to_s.downcase.to_clean_sym
    end

    def check(hash)
      return if events && !events.include?(hash[:event])
      value = hash.hpath(target)&.first
      return if value.nil? && operator != :exists
      match = thresholds.find do |_sev, threshold|
        next if threshold.nil?
        begin
          result = TaskVault::Operators.send(operator, value, threshold)
          invert? ? !result : result
        rescue => e
          parent&.queue_warn(e)
        end
      end
      value = value.round(round) if round && value.is_a?(Numeric)
      if match
        send_alert(value: value, severity: match[0], threshold: match[1])
      else
        send_clear(value: value)
      end
    rescue => e
      parent&.queue_error(e)
    end

    def send_alert(details = {})
      self.triggered_count += 1
      self.last_triggered = Time.now
      parent&.queue_msg(
        default_alert(details).merge(details)
      )
    end

    def hostname
      Socket.gethostname
    end

    def send_clear(details = {})
      send_alert(details.merge(severity: :info, event: :clear))
    end

    def thresholds
      {
        critical: critical,
        major:    major,
        minor:    minor,
        warn:     warn,
        info:     info
      }
    end

    protected

    def build_message(details = {})
      msg = message.dup
      msg.scan(/\{{2}.*?\}{2}/i).uniq.each do |placeholder|
        attribute = placeholder[2..-3].to_sym
        msg = msg.gsub(placeholder, (details[attribute]).to_s)
      end
      msg
    end

    # Sets the default alert attributes. More can be added by redefining this
    # and called super.merge(new_attributes: 1) (for example)
    def default_alert(details = {})
      hash = {
        name:        name,
        type:        self.class.to_s,
        event_key:   event_key(details),
        description: describe,
        hostname:    hostname,
        event:       :alert,
        operator:    operator,
        severity:    :warning
      }
      hash[:message] = build_message(details.merge(hash).merge(metadata))
      hash
    end
  end
end
