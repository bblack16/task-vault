require 'socket'

class TaskVault

  class Sentry < Component
    attr_reader :port, :controller, :key, :interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most use cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def running?
      @controller.running? && (@thread && @thread.alive?)
    end

    def stop
      @controller.stop
      super
    end

    def restart
      stop
      start
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

    def method_missing *args, **named
      if @controller.respond_to?(args.first)
        @controller.send(args.first, *args[1..-1], **named)
      else
        super(*args, **named)
      end
    end

    protected

      def setup_defaults
        @port = 2016
        @key = 'changeme'
        @interval = 5
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
        @thread = Thread.new {
          queue_msg("Sentry is up and listening on port #{@port}.", severity: 6)
          loop do
            begin
              @parent.courier.handlers.each do |handler|
                @controller.register( "handler_#{handler.name.to_clean_sym}".to_sym => handler )
              end
              sleep(interval)
            rescue StandardError, Exception => e
              queue_msg(e, severity: 2)
            end
          end
        }
      end

    end

end
