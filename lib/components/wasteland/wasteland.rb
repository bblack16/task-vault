# frozen_string_literal: true
require_relative 'server'
require_relative 'component'
require_relative 'sub_component'

module TaskVault
  class Wasteland < ServerComponent
    attr_int :port, default: 4567, serialize: true
    attr_str :bind, default: 'localhost', serialize: true
    attr_hash :settings, default: {}, serialize: true

    def self.new(*args, &block)
      return @wasteland if @wasteland
      @wasteland = super
    end

    VERSION = '0.1.0'

    def self.wasteland
      @wasteland
    end

    def start
      return if running?
      queue_info('Welcome to the Wasteland, wanderer! (Started)')
      super
    end

    def stop
      if running?
        Wasteland::Server.quit!
        queue_info('The Wasteland has been nuked... (Stopped)')
      else
        queue_info('Stop called, but the server is not currently running...')
      end
      super
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
      Wasteland::Server.set(settings.deep_merge(port: port, bind: bind, quiet: true, server_settings: { signals: false }))
      queue_info("Starting Sinatra server on port #{port} bound to #{bind}.")
      Wasteland::Server.run!
    ensure
      Wasteland::Server.quit!
    end

    def msg_metadata
      { port: port, bind: bind }
    end

  end
end
