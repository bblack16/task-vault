require_relative 'logger'

module TaskVault
  module MessageHandlers
    class Default < Logger

      attr_of ::Logger, :logger, default_proc: proc { BBLib.logger }

      protected

      def process_message(message)
        logger.send(message.severity || :info, format_message(message))
      rescue => e
        puts e, e.backtrace
      end

      def format_message(message)
        str = message.content
        if str.is_a?(Exception)
          str = "#{str}\n\t#{str.backtrace.join("\n\t")}"
        else
          str = str.to_s
        end
        "#{message._source.class.to_s.split('::').last} (#{message._source.id}) - #{str}"
      end

    end
  end
end
