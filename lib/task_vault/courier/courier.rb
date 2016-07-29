require_relative 'message_handler'
require_relative 'message_handlers/task_vault_handler'
require_relative 'message_handlers/task_vault_logger'

class TaskVault

  class Courier < Component
    attr_reader :handlers, :interval, :path, :load_interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most cases
    # As a general rule, the lower the interval, the higher the CPU usage
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def load_interval= l
      @load_interval = l.nil? ? nil : BBLib.keep_between(l, 0, nil)
    end

    def path= path
      @path = path.nil? ? nil : path.pathify
    end

    def start
      @handlers.each{ |h| h.start }
      super()
    end

    def stop
      @handlers.each{ |h| h.stop }
      super()
    end

    def add mh, overwrite = true
      if @handlers.any?{ |a| a.name == mh.name }
        match = @handlers.find{ |h| h.name == mh.name }
        if overwrite && match.serialize != mh.serialize
          match.stop
          while hash = match.read_msg
            mh.queue_msg(hash.delete(:msg), hash.delete(:handlers), hash)
          end
          @handlers.delete_if{ |h| h.name == mh.name}
          @handlers.push mh
          mh.start
          queue_msg("Overwrote existing version of '#{mh.name}' with a new copy found in the config directory", severity: 5)
        end
      else
        @handlers.push mh
        mh.start
        queue_msg("Added new handler to Courier: #{mh.name}.", severity: 6)
      end
    end

    alias_method :add_handler, :add

    def remove name
      @handlers.delete_if{ |h| h.name == name }
    end

    def list
      @handlers.map{ |h| h.name }
    end

    alias_method :handler_list, :list

    alias_method :remove_handler, :remove

    def load
      begin
        BBLib.scan_files(@path, filter: ['*.yaml', '*.json', '*.yml'], recursive: true).each do |file|
          begin
            add_handler MessageHandler.load(file)
          rescue StandardError, Exception => e
            queue_msg("Courier failed to load message handler from #{file}. Please fix or remove this file. #{e}", severity: 4)
          end
        end
      rescue StandardError, Exception => e
        queue_msg(e, severity: 2)
      end
    end

    alias_method :load_handlers, :load

    def save format = :json
      begin
        @handlers.map do |handler|
          [handler.name, handler.save(@path)]
        end.to_h
      rescue StandardError, Exception => e
        queue_msg(e, severity: 2)
      end
    end

    alias_method :save_handlers, :save

    protected

      def init_thread
        @thread = Thread.new {
          begin
            index = 0
            loop do
              start = Time.now.to_f
              if @load_interval && index == 0 && !@path.nil?
                queue_msg("Courier is reloading message handlers from disk...", severity: 8)
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
                      if h
                        handler = @handlers.find{ |hand| hand.name == h }
                        handler.queue details[:msg], **details[:meta] if handler
                      end
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
        @handlers = [TaskVaultHandler.new]
        self.interval = 0.5
        self.load_interval = 120
      end

  end

end
