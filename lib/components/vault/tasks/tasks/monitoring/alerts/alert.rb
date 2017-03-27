module TaskVault
  module Tasks
    class Alert < BBLib::LazyClass

      SEVERITIES = [:clear, :info, :warn, :minor, :major, :critical]

      attr_str :message, default: '{{hostname}}: {{severity}}', serialize: true, always: true
      attr_of TaskVault::Component, :parent, default: nil, allow_nil: true
      attr_element_of SEVERITIES, :severity, default: :warn, serialize: true, allow_nill: true

      # Redefine this is subclasses
      def describe
        "#{self.class} - #{severity}"
      end

      # Used to tie clears and alerts together. Redefine this in subclasses.
      # Alert details are passed in so they can be used to generate the key (as a hash)
      def event_key(details = {})
        self.class.to_s
      end

      def check(*args)
        # Redefine this. This is called and passed the data it is meant to check against
      end

      def send_alert(details = {})
        parent&.queue_msg(
          default_alert(details).merge(details)
        )
      end

      def hostname
        Socket.gethostname
      end

      def send_clear(details = {})
        send_alert(details.merge(severity: :clear, event: :clear))
      end

      protected

      def build_message(details = {})
        msg = message.dup
        msg.scan(/\{{2}.*?\}{2}/i).uniq.each do |placeholder|
          attribute = placeholder[2..-3]
          msg = msg.gsub(placeholder, (details[attribute.to_sym] || details[attribute] || (send(attribute) rescue nil)).to_s)
        end
        msg
      end

      # Sets the default alert attributes. More can be added by redefining this
      # and called super.merge(new_attributes: 1) (for example)
      def default_alert(details = {})
        {
          type:        self.class.to_s,
          event_key:   event_key(details),
          message:     build_message(details),
          description: describe,
          host:        hostname,
          severity:    severity,
          event:       :alert
        }
      end
    end
  end
end
