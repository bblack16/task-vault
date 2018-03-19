require_relative 'logger'

module TaskVault
  module MessageHandlers
    class Default < Logger

      attr_of ::Logger, :logger, default_proc: proc { BBLib.logger }

      protected

      def process_message(message)
        logger.send(message[:severity] || :info, format_message(message))
      rescue => e
        puts e, e.backtrace
      end

      def format_message(message)
        str = message[:message]
        if str.is_a?(Exception)
          str = "#{e}\n\t#{e.backtrace.join("\n\t")}"
        else
          str = str.to_s
        end
        "#{message[:_source].class} (#{message[:_source].id}) - #{str}"
      end

    end
  end
end
