# frozen_string_literal: true
module TaskVault
  class Radio < Component
    after :reset, :port=, :key=

    attr_int_between 0, nil, :port, default: 2016, serialize: true, always: true
    attr_string :key, default: 'changeme', serialize: true, always: true
    attr_reader :controller

    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      @controller.stop
      super
    end

    def running?
      @controller.running?
    end

    def method_missing(*args)
      @controller.send(*args)
    end

    def respond_to_missing(method, include_private = false)
      @controller.respond_to?(method) || super
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
      sleep(1) while @controller.running?
    end
  end
end
