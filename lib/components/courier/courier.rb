# frozen_string_literal: true
require_relative 'handlers/_handlers'

module TaskVault
  class Courier < ServerComponent
    attr_valid_dir :path, allow_nil: true, serialize: true, always: true
    attr_float_between 0.001, nil, :interval, default: 0.5, serialize: true, always: true
    attr_int_between 1, nil, :load_interval, default: 120, allow_nil: true, serialize: true, always: true
    attr_ary_of MessageHandler, :message_handlers, default: [], serialize: true, always: true
    attr_sym :fallback, default: :default, allow_nil: true, serialize: true, always: true

    def start
      queue_info('Starting up component.')
      message_handlers.all?(&:start) && super
    end

    def stop
      queue_info('Stopping component.')
      sleep(BBLib.keep_between(interval, 0, 2))
      super
      message_handlers.all?(&:stop)
    end

    def self.description
      'Getting things from point A to B since 2016. Courier is a message handler for TaskVault. It\'s purpose in life is to read messages ' \
      'from the components in the TaskVault server and pass them off to the appropriate handler. '
    end

    def add(handler)
      handler = build_handler(handler) if handler.is_a?(Hash)
      raise ArgumentError, "Invalid object type passed as message handler: #{handler.class}." unless handler.is_a?(MessageHandler)
      if match = message_handlers.find { |n| n.name == handler.name }
        if match.serialize != handler.serialize
          match.stop
          handler.queue(*match.read_all_msgs)
          message_handlers.delete(match)
          message_handlers << handler
          handler.start
          queue_info("Overwrote the existing version of '#{match.name}'.")
        end
      else
        message_handlers << handler
        handler.start
        queue_info("Added a new message handler to Courier: #{handler.name}")
      end
      handler.parent = self
      handler.name
    end

    alias add_msg_handler add
    alias add_message_handler add

    def remove(name)
      if name.is_a?(Fixnum)
        handler = message_handlers[name]
        message_handlers.delete_at(name)&.stop
        handler
      elsif name.is_a?(MessageHandler)
        message_handlers.delete(name)&.stop
        name
      else
        matches = message_handlers.find_all { |m| m.name == name.to_sym }
        matches.each(&:stop)
        matches
      end
    end

    def list
      message_handlers.map(&:name)
    end

    def has_handler?(name)
      message_handlers.any? { |m| m.name == name.to_s.to_sym }
    end

    def retrieve(name)
      message_handlers.find { |m| m.name == name.to_s.to_sym }
    end

    def save(name, format: :yaml)
      if handler = retrieve(name)
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
          queue_error(e)
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
        new_name = "#{klass}#{i += 1}".to_sym while has_handler?(new_name)
        handler.name = new_name
      end
      handler
    end

    def find_matching(opts)
      message_handlers.find do |h|
        opts.all? do |k, v|
          if k == :class
            h.class.to_s == v.to_s || h.class.aliases.include?(v.to_s)
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
      require_relative 'api'
    end

    def lazy_init(*args)
      super
      add(Handlers::TaskVaultHandler.new(name: :default)) if message_handlers.empty?
    end

    def run
      index = 0
      loop do
        start = Time.now
        if @load_interval && index.zero? && @path
          # LOAD message handlers from disk
          queue_debug("Reloading message handlers from disk @ #{@path}: current total = #{@message_handlers.size}")
          reload
          queue_debug("Finished reloading message handlers: current total = #{@message_handlers.size}")
          index = @load_interval.to_i
        end

        components = [
          @parent.components,
          @message_handlers
        ].flatten.compact

        components.each do |component|
          while component.has_msg?
            msg = component.read_msg
            next unless msg
            (msg[:handlers] || [fallback]).each do |handler|
              if has_handler?(handler)
                retrieve(handler).push(msg)
              elsif fallback && has_handler?(fallback)
                retrieve(fallback).push(msg)
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
