

class TaskVault

  class TaskVaultHandler < MessageHandler
    attr_reader :time_format, :level

    def time_format= format
      @time_format = format.to_s
    end

    def level= lvl
      @level = BBLib.keep_between(lvl, 0, 10)
    end

    def process_message
      begin
        data = read_msg
        if (data[:severity] || 0).to_i <= @level
          puts construct_msg(data).join(' - ')
        end
      rescue Exception => e
        puts e
      end
    end

    protected

      SEVERITIES = {
        0 => 'UNKN',
        1 => 'FATAL',
        2 => 'ERROR',
        3 => 'WARN',
        4 => 'WARN',
        5 => 'INFO',
        6 => 'INFO',
        7 => 'DEBUG',
        8 => 'DEBUG',
        9 => 'DEBUG',
        10 => 'DEBUG'
      }

      def setup_defaults
        super
        @time_format = '%Y-%m-%d %H:%M:%S.%L'
        @level = 10
      end

      def construct_msg data
        [
          (data.include?(:time) && data[:time].is_a?(Time) ? data[:time] : Time.now).strftime(time_format),
          SEVERITIES[(data[:severity] || 0).to_i],
          (data[:component] || '?').to_s.sub('TaskVault::', ''),
          "#{data[:task_name] ? "#{data[:task_name]}: " : ''}" +
          "#{data[:msg]}#{data[:msg].is_a?(Exception) ? ': ' + data[:msg].backtrace.join : ''}"
        ]
      end

      def setup_serialize_fields
         [:level, :time_format]
      end

  end

end
