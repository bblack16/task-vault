# frozen_string_literal: true
module TaskVault
  class Radio < ServerComponent
    after :port=, :key=, :reset

    attr_int_between 0, nil, :port, default: 2016, serialize: true, always: true
    attr_string :key, default: 'changeme', serialize: true, always: true
    attr_array_of String, :components, default: [], add_rem: true, serialize: true, always: true
    attr_of Ava::Controller, :controller, default_proc: proc { |x| Ava::Controller.new(port: x.port, key: x.key) }
    attr_reader :controller, serialize: false

    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      controller.stop
      super
    end

    def self.description
      'Remote control your TaskVault server! Radio provides a controller that can host the TaskVault server and its components over a TCP socket.' \
      'It utilizes the Ava library to do this and can be connected to via an Ava::Client or the TaskVault::Client.'
    end

    def running?
      controller.running?
    end

    def method_missing(*args)
      controller.send(*args)
    end

    def respond_to_missing?(method, include_private = false)
      controller.respond_to?(method) || super
    end

    protected

    def register_objects
      ([parent] + parent.components).each do |component|
        name = component.is_a?(TaskVault::Server) ? 'server' : component.name
        controller.register(name => component) if components.empty? || components.include?(component.name.to_s)
      end
    end

    def reset
      controller.key = key
      controller.port = port
      restart if running?
    end

    def run
      controller.start
      sleep(1)
      register_objects
      sleep(1) while controller.running?
    end
  end
end
