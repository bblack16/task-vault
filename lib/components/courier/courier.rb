require_relative 'handlers/_handlers'

module TaskVault

  class Courier < Component
    attr_valid_dir :path, allow_nil: true, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 0.5, serialize: true, always: true
    attr_int_between 1, nil, :load_interval, default: 120, allow_nil: true, serialize: true, always: true
    attr_reader :message_handlers

    def start
      queue_msg("Starting up component.", severity: :info)
      @message_handlers.all?{ |n, mh| mh.start } && super
    end

    def stop
      queue_msg("Stopping component.", severity: :info)
      sleep(BBLib::keep_between(@interval, 0, 2))
      super
      @message_handlers.all?{ |n, mh| mh.stop }
    end

    def add handler
      raise ArgumentError, "Invalid object type passed as message handler: #{handler.class}." unless handler.is_a?(MessageHandler)
      if match = @message_handlers.find{ |n, mh| n == handler.name }
        match = match[1]
        if match.serialize != handler.serialize
          match.stop
          handler.queue(*match.read_all_msgs)
          @message_handlers[handler.name] = handler
          handler.start
          queue_msg("Overwrote the existing version of '#{match.name}'.", severity: :info)
        end
      else
        @message_handlers[handler.name] = handler
        handler.start
        queue_msg("Added a new message handler to Courier: #{handler.name}", severity: :info)
      end
    end

    alias_method :add_msg_handler, :add
    alias_method :add_message_handler, :add

    def remove name
      handler = @message_handlers.delete(name)
      handler.stop if handler
      handler
    end

    def list
      @message_handlers.keys
    end

    def has_handler? name
      @message_handlers.include?(name)
    end

    def save name, format: :yaml
      if handler = @message_handlers[name]
        path = "#{@path}/message_handlers/#{name}".pathify
        case format
        when :yaml, :yml
          path += '.yml'
          handler.serialize.to_yaml.to_file(path, mode: 'w')
        when :json
          path += '.json'
          handler.serialize.to_json.to_file(path, mode: 'w')
        else
          raise ArgumentError, "Invalid format '#{format}'. Must be :yaml or :json."
        end
        File.exists?(path)
      else
        false
      end
    end

    def save_all format: :yaml
      @handlers.all? do |name, data|
        save(name, format: format) rescue false
      end
    end

    def reload
      begin
        BBLib.scan_files(@path, filter: ['*.json', '*.yml', '*.yaml'], recursive: @recursive).each do |file|
          begin
            add(MessageHandler.load(file))
          rescue StandardError => e
            queue_msg(e, severity: :error)
          end
        end
      rescue StandardError => e
        queue_msg(e, severity: :error)
      end
    end

    protected

    def setup_defaults
      @message_handlers = { default: TaskVaultHandler.new }
      serialize_method :message_handlers, always: true
    end

    def run
      index = 0
      loop do
        start = Time.now
        if @load_interval && index == 0 && @path
          # LOAD message handlers from disk
          queue_msg("Reloading message handlers from disk @ #{@path}: current total = #{@message_handlers.size}", severity: :debug)
          reload
          queue_msg("Finished reloading message handlers: current total = #{@message_handlers.size}", severity: :debug)
          index = @load_interval.to_i
        end

        components = [
          @parent.components.values,
          @parent.vault.all_tasks,
          @parent.courier.message_handlers.values
        ].flatten.compact

        components.each do |component|
          while component.has_msg?
            msg = component.read_msg
            (msg[:handlers] || [:default]).each do |handler|
              if has_handler?(handler)
                @message_handlers[handler].push(msg)
              else
                p "Handler not found for #{handler}"
              end
            end
          end
        end

        index -= 1 if @load_interval
        sleep_time =  @interval - (Time.now.to_f - start.to_f)
        sleep(sleep_time <= 0 ? 0 : sleep_time)
      end
    end

  end

end
