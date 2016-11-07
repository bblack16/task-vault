# frozen_string_literal: true
module TaskVault
  module PutsQueue
    def queue_msg_override(msg, **data)
      queue_msg(msg, **data)
    end

    alias print queue_msg_override
    alias puts queue_msg_override
  end
end
