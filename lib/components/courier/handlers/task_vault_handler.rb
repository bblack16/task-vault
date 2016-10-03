module TaskVault

  class TaskVaultHandler < MessageHandler

    SEVERITIES = {
      fatal: 'FATAL',
      error: 'ERROR',
      warn:  'WARN ',
      info:  'INFO ',
      debug: 'DEBUG'
    }

    attr_string :time_format, default: '%Y-%m-%d %H:%M:%S.%L'
    attr_element_of SEVERITIES, :level, default: :debug

    protected

      def process_message
        msg = read
        return nil unless severity_check(msg[:severity])
        puts construct_msg(msg)
      end

      def construct_msg msg
        [
          build_time(msg[:time]),
          SEVERITIES[msg[:severity]] || 'UNKN ',
          msg[:component].to_s.sub('TaskVault::', ''),
          build_name(msg),
          build_message(msg[:msg])
        ].compact.join(' - ')
      end

      def build_time time
        (time.is_a?(Time) ? time : Time.now).strftime(@time_format)
      end

      def build_message msg
        if msg.is_a?(Exception)
          "#{msg}\n#{msg.backtrace.join('\n')}"
        else
          msg.to_s
        end
      end

      def severity_check severity
        begin
          SEVERITIES.keys.find_index(severity) <= SEVERITIES.keys.find_index(@level)
          true
        rescue StandardError => e
          puts e, severity
        end
      end

      def build_name msg
        return nil unless msg[:name]
        "#{msg[:name]}#{msg[:id] ? " (ID #{msg[:id]})" : nil}"
      end

      def setup_serialize
        super
        serialize_method :time_format, always: true
        serialize_method :level, always: true
      end

  end

end
