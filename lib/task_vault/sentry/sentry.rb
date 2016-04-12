require 'socket'

class TaskVault

  class Sentry < Component
    attr_reader :port, :controller, :key

    def running?
      @controller.running?
    end

    def start
      @started = Time.now
      @controller.start
    end

    def stop
      @stopped = Time.now
      @controller.stop
    end

    def restart
      @controller.restart
    end

    def port= port
      @port = port.to_i
      @controller.port = @port
      @controller.restart
    end

    def key= key
      @key = key.to_s
      @controller.key = @key
      @controller.restart
    end

    protected

      def setup_defaults
        @port = 2016
        @key = 'changeme'
        @controller = Ava::Controller.new(port: @port, key: @key)
        @controller.register(
          task_vault: @parent,
          vault: @parent.vault,
          courier: @parent.courier,
          protectron: @parent.protectron,
          workbench: @parent.workbench,
          sentry: self
        )
      end

      def init_thread
        @controller.start
        queue_msg("INFO - Sentry is up and listening on port #{@port}.")
      end

    end

end
