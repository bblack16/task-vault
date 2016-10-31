
module TaskVault

  class Overseer < Component
    attr_reader :server

    protected

    def run

      loop do
        Server.parent = @parent
        Server.run!
        sleep(30)
      end
    end

  end

end

require_relative 'server'
