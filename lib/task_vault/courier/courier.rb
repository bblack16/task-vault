require_relative 'message_handler'

class TaskVault

  class Courier < Component
    attr_reader :handlers, :interval, :path, :load_interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most use cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def load_interval= l
      @load_interval = l.nil? ? nil : BBLib.keep_between(l, 0, nil)
    end

    def path= path
      @path = path.to_s.gsub('\\', '/')
    end

    def start
      @handlers.each{ |h| h.start }
      super()
    end

    def stop
      @handlers.each{ |h| h.stop }
      super()
    end

    def add_handler mh, overwrite = true
      # TODO Implement something to achieve the below line
      # mh = MessageHandler.new(**mh) if mh.is_a?(Hash)
      if @handlers.any?{ |a| a.name == mh.name }
        match = @handlers.find{ |h| h.name == mh.name }
        if overwrite && match.serialize != mh.serialize
          match.stop
          queue = match.message_queue
          queue.each do |hash|
            mh.queue_msg(hash.delete(:msg), hash.delete(:handlers), hash)
          end
          @handlers.delete(match)
          @handlers.push mh
        end
      else
        @handlers.push mh
      end
    end

    def load_handlers
      begin
        BBLib.scan_files(@path, filter: ['*.yaml', '*.json', '*.yml'], recursive: true).each do |file|
          begin
            add_handler MessageHandler.load(file)
          rescue StandardError, Exception => e
            queue_msg("WARN - Courier failed to load message handler from #{file}. Please fix or remove this file. #{e}")
          end
        end
      rescue StandardError, Exception => e
        queue_msg(e)
      end
    end

    def handler_list
      @handlers.map{ |h| h.name }
    end

    protected

      def init_thread
        @thread = Thread.new {
          begin
            index = 0
            loop do
              start = Time.now.to_f
              if @load_interval && index == 0
                queue_msg("DEBUG - Courier is reloading message handlers from disk...")
                load_handlers
                index = @load_interval
              end

              if @parent.is_a?(TaskVault)
                objects = [
                            @parent.vault,
                            @parent.protectron,
                            @parent.workbench,
                            @parent.sentry,
                            self
                          ]
                @parent.vault.tasks.each{ |t| objects << t }
                objects.each do |obj|
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

              index-=1 if @load_interval
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
        self.load_interval = 120
      end

  end

end
