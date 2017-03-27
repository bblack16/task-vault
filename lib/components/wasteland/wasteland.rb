# frozen_string_literal: true
require_relative 'server' if (require 'sinatra' rescue false)
require_relative 'component'
require_relative 'sub_component'
# require_relative 'components/workbench'
# require_relative 'components/vault'
# require_relative 'components/courier'

module TaskVault
  class Wasteland < ServerComponent
    attr_int :port, default: 4567, serialize: true
    attr_str :bind, default: 'localhost', serialize: true

    def self.new(*args, &block)
      return @wasteland if @wasteland
      @wasteland = super
    end

    VERSION = '0.1.0'

    def self.wasteland
      @wasteland
    end

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
      Server.set(port: port, bind: bind)
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
