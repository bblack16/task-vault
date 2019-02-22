module TaskVault
  module MessageHandlers
    class Logger < MessageHandler

      attr_of ::Logger, :logger, default_proc: proc { BBLib.logger }

      protected

      def process_message(message)
        logger.send(message.severity || :info, message.content)
      rescue => e
        puts e, e.backtrace
      end

    end
  end
end
