# frozen_string_literal: true
require_relative 'server'
require_relative 'components/wasteland_component'
require_relative 'components/vault'

module TaskVault
  class Wasteland < ServerComponent

    VERSION = '0.1.0'

    def start
      queue_msg('Welcome to the Wasteland, wanderer! (Started)', severity: :info)
      super
    end

    def stop
      Server.quit!
      queue_msg('The Wasteland has been nuked... (Stopped)', severity: :info)
      super
    end

    def running?
      !@thread.nil? && @thread.alive?
    end

    def self.current_server
      @current_server
    end

    def self.current_server=(server)
      @current_server = server
    end

    protected

    def setup_defaults
      Wasteland.current_server = self
    end

    def run
      Server.run!
      while Server.running?
        sleep(10)
      end
    end

    def msg_metadata
      {}
    end

  end
end
