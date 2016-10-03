module TaskVault

  class Radio < Component
    after :reset, :port=, :key=

    attr_int_between 0, nil, :port, default: 2016
    attr_string :key, default: 'changeme'
    attr_reader :controller

    def start
      queue_msg("Starting up component.", severity: :info)
      super
    end

    def stop
      queue_msg("Stopping component.", severity: :info)
      @controller.stop
      super
    end

    def running?
      @controller.running?
    end

    def method_missing *args
      @controller.send(*args)
    end

    protected

      def setup_defaults
        @controller = Ava::Controller.new(port: @port, key: @key)
      end

      def register_objects
        @controller.register(
          overseer:  @parent,
          vault:     @parent.vault,
          courier:   @parent.courier,
          sentry:    @parent.sentry,
          workbench: @parent.workbench,
          radio:     self
        )
      end

      def reset
        @controller.key = @key
        @controller.port = @port
        restart if running?
      end

      def run
        @controller.start
        sleep(1)
        register_objects
        while @controller.running?
          sleep(1)
        end
      end

  end

end
