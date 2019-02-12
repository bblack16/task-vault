module TaskVault
  module MessageHandlers
    class Eval < MessageHandler

      attr_str :code, aliases: [:evaluation], arg_at: :block

      protected

      def process_message(message)
        eval(code)
      rescue => e
        puts e, e.backtrace
      end

    end
  end
end
