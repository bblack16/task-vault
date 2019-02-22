require_relative '../message_handler'

BBLib.scan_files(File.expand_path('../../message_handlers', __FILE__), '*.rb') do |file|
  require_relative file
end

module TaskVault
  class Courier
    include Runnable
    include BBLib::Prototype

    attr_of Object, :parent, default_proc: proc { TaskVault::Server.prototype }, serialize: false
    attr_ary_of MessageHandler, :handlers, default_proc: proc { [MessageHandlers::Default.new] }, remover: true, remover_name: :remove

    def add(handler = {}, &block)
      if handler.is_a?(Hash)
        handler[:type] = :proc if block && !handler[:type]
        handler = MessageHandler.new(handler, &block)
      end
      handlers << handler unless handlers.include?(handler)
      handler
    end

    def process(message)
      handlers.each do |handler|
        next unless handler.listen?(message)
        handler.push(message)
      end
    end

    protected

    def simple_setup
      self.interval = 0.1
    end

    def components
      parent ? parent.components : []
    end

    def start_handlers
      handlers.each do |handler|
        handler.start unless handler.running?
      end
    end

    def run(*args, &block)
      start_handlers
      components.each do |component|
        queue = component.message_queue
        until queue.empty?
          message = queue.read
          next unless message
          process(message)
        end
      end
    end

  end
end
