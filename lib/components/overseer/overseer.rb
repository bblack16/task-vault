
module TaskVault
  class Overseer < Component
    attr_int_between 0, nil, :port, default: 4567, serialize: true, always: true
    attr_str :bind, default: '0.0.0.0', serialize: true, always: true
    attr_reader :server

    def start
      queue_msg("Starting Overseer on #{@bind}:#{@port}.", severity: :info)
      super
    end

    def stop
      queue_msg("Stopping Overseer running at #{@bind}:#{@port}.", severity: :info)
      Server.quit!
      super
    end

    protected

    def run
      Server.parent = @parent
      Server.set port: @port, bind: @bind
      Server.precompile!
      Server.run!
    end
  end
end

require_relative 'server'
