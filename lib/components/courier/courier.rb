# frozen_string_literal: true
require_relative 'handlers/_handlers'

module TaskVault
  class Courier < ServerComponent
    attr_valid_dir :path, allow_nil: true, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 0.5, serialize: true, always: true
    attr_int_between 1, nil, :load_interval, default: 120, allow_nil: true, serialize: true, always: true
    attr_reader :message_handlers

    def start
      queue_msg('Starting up component.', severity: :info)
      @message_handlers.all? { |_n, mh| mh.start } && super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      sleep(BBLib.keep_between(@interval, 0, 2))
      super
      @message_handlers.all? { |_n, mh| mh.stop }
    end

    def self.description
      'Getting things from point A to B since 2016. Courier is a message handler for TaskVault. It\'s purpose in life is to read messages from ' \
      'from the components in the TaskVault server and pass them off to the appropriate handler. '
    end

    def add(handler)
      handler = build_handler(handler) if handler.is_a?(Hash)
      raise ArgumentError, "Invalid object type passed as message handler: #{handler.class}." unless handler.is_a?(MessageHandler)
      if match = @message_handlers.find { |n, _mh| n == handler.name }
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
      handler.name
    end

    alias add_msg_handler add
    alias add_message_handler add

    def remove(name)
      handler = @message_handlers.delete(name)
      handler&.stop
      handler
    end

    def list
      @message_handlers.keys
    end

    def has_handler?(name)
      @message_handlers.include?(name)
    end

    def save(name, format: :yaml)
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
        File.exist?(path)
      else
        false
      end
    end

    def save_all(format: :yaml)
      @handlers.all? do |name, _data|
        begin
          save(name, format: format)
        rescue
          false
        end
      end
    end

    def reload
      BBLib.scan_files(@path, '*.json', '*.yml', '*.yaml', recursive: @recursive).each do |file|
        begin
          add(MessageHandler.load(file))
        rescue StandardError => e
          queue_msg(e, severity: :error)
        end
      end
    rescue StandardError => e
      queue_msg(e, severity: :error)
    end

    def build_handler(opts)
      if match = find_matching(opts)
        return match
      end
      handler = MessageHandler.load(opts)
      unless handler.name
        klass = handler.class.to_s.downcase.split('::').last
        new_name = klass.to_sym
        i = 1
        while has_handler?(new_name)
          new_name = "#{klass}#{i += 1}".to_sym
        end
        handler.name = new_name
      end
      handler
    end

    def find_matching(opts)
      message_handlers.values.find do |h|
        opts.all? do |k, v|
          if k == :class
            h.class.to_s == k.to_s || h.class.aliases.include?(k.to_s)
          elsif !h.respond_to?(k)
            true
          else
            h.send(k) == v
          end
        end
      end
    end

    def self.registry
      TaskVault::MessageHandler.descendants
    end

    protected

    def setup_defaults
      @message_handlers = { default: Handlers::TaskVaultHandler.new }
      serialize_method :message_handlers, always: true
    end

    def run
      index = 0
      loop do
        start = Time.now
        if @load_interval && index.zero? && @path
          # LOAD message handlers from disk
          queue_msg(
            "Reloading message handlers from disk @ #{@path}: current total = #{@message_handlers.size}",
            severity: :debug
          )
          reload
          queue_msg("Finished reloading message handlers: current total = #{@message_handlers.size}", severity: :debug)
          index = @load_interval.to_i
        end

        components = [
          @parent.components.values,
          @message_handlers.values
        ].flatten.compact

        components.each do |component|
          while component.has_msg?
            msg = component.read_msg
            next unless msg
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
        sleep_time = @interval - (Time.now.to_f - start.to_f)
        sleep(sleep_time.negative? ? 0 : sleep_time)
      end
    end
  end
end
