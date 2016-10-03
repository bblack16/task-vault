module TaskVault::PutsQueue

  def queue_msg_override msg, **data
    self.queue_msg(msg, **data)
  end

  alias_method :print, :queue_msg_override
  alias_method :puts, :queue_msg_override

end
