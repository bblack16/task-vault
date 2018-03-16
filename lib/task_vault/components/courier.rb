require_relative 'message_handler'

module TaskVault
  class Courier
    include Runnable
    include BBLib::Prototype

    attr_of Object, :parent, default_proc: proc { TaskVault::Server.prototype }
    attr_ary_of MessageHandler, :handlers, default_proc: proc { [MessageHandler.new] }, add_rem: true, adder_name: :add, remover_name: :remove

    def process(message)
      handlers.each do |handler|
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
