

module TaskVault

  class Overseer < Component
    require_relative 'server'
    attr_reader :server

    protected

    def run
      @server = Overseer::Server
      @server.parent = @parent
      @server.run!
      p 'Starting server'
      sleep(10) while @server.running?
    end

  end

end
