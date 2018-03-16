module TaskVault
  module PutsOverride

    def queue_message_override(msg, data = {})
      queue_message(msg, data)
    end

    alias print queue_message_override
    alias puts queue_message_override

  end
end
