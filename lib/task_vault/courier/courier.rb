require_relative 'message_handler'

class TaskVault

  class Courier < Component
    attr_reader :handlers, :interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def start
      @handlers.each{ |h| h.start }
      super()
    end

    def stop
      @handlers.each{ |h| h.stop }
      super()
    end

    protected

      def init_thread
        @thread = Thread.new {
          begin
            loop do
              start = Time.now.to_f
              if @parent.is_a?(TaskVault)
                [@parent.vault, @parent.protectron, @parent.workbench, @parent.overworld, self].each do |obj|
                  while obj.has_msg?
                    details = obj.read_msg
                    details[:handlers] = [:default] if details[:handlers].empty?
                    details[:handlers].each do |h|
                      handler = @handlers.find{ |hand| hand.name = h}
                      handler.queue details[:msg], **details[:meta] if handler
                    end
                  end
                end
              end

              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            @handlers.find{ |h| h.name == :default}.queue(e)
            e
          end
        }
      end

      def setup_defaults
        @handlers = [MessageHandler.new]
        self.interval = 0.5
      end

  end

end
