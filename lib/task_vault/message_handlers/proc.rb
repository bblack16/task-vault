module TaskVault
  module MessageHandlers
    class Proc < MessageHandler

      attr_of ::Proc, :logger, arg_at: :block

      protected

      def process_message(message)
        logger.call(message)
      rescue => e
        puts e, e.backtrace
      end

    end
  end
end
