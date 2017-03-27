# frozen_string_literal: true
module TaskVault
  class Component < BBLib::LazyClass
    attr_of Object, :parent, allow_nil: true, default: nil
    attr_sym :name, required: true, serialize: true
    attr_handlers :handlers, default: [:default], serialize: true, always: true, add_rem: true
    attr_int_between 0, nil, :history_limit, default: 100, serialize: true, always: true
    attr_int_between 0, nil, :message_limit, default: 100_000, serialize: true, always: true
    attr_hash :metadata, default: {}, serialize: true, always: true
    attr_bool :use_inventory, default: true, serialize: true, always: true
    attr_of Hash, :event_handlers, default: {}, serialize: true, to_serialize_only: true
    attr_reader :message_queue, :thread, :started, :stopped, :history

    after :register_handlers, *attrs.find_all { |_n, o| o[:type] == :handler }.map(&:first).map { |r| "#{r}=".to_sym } + [:lazy_init, :parent=, :add_handlers]
    after :register_event_handlers, :event_handlers=, :parent=

    def start
      init_thread unless running?
      @started = Time.now
      running?
    end

    def stop
      @stopped = Time.now if running?
      @thread&.kill
      sleep(0.2)
      !running?
    end

    def restart
      stop && start
    end

    def disown
      self.parent = nil
      self
    end

    def running?
      !@thread.nil? && @thread.alive?
    end

    def uptime
      running? && @started ? Time.now - @started : 0
    end

    def queue_msg(msg, **data)
      msg = {
        msg:      msg,
        handlers: pick_handlers(data),
        severity: (msg.is_a?(Exception) ? :error : :info),
        event:    :general
      }.merge(compile_msg_data(**data))
      @history.unshift(msg.dup)
      @history.pop while @history.size > @history_limit
      @message_queue.push(msg)
      @message_queue.shift while @message_queue.size > @message_limit
    end

    alias queue_message queue_msg

    [:verbose, :debug, :info, :warn, :error, :fatal].each do |sev|
      define_method "queue_#{sev}" do |msg, **data|
        queue_msg(msg, **data.merge(severity: sev))
      end
    end

    def read_msg
      @message_queue.shift
    end

    def read_all_msgs
      all = []
      @message_queue.size.times do
        all.push read_msg
      end
      all
    end

    def has_msg?
      !@message_queue.empty?
    end

    def inventory
      return nil unless parent && use_inventory?
      parent.components_of(Inventory).first
    end

    # Custom inspect to able to hide unwanted variables
    def inspect
      vars = instance_variables.map do |v|
        "#{v}=#{instance_variable_get(v).inspect}" unless hide_on_inspect.include?(v)
      end.compact.join(', ')
      "<#{self.class}:0x#{object_id} #{vars}>"
    end

    def save(path = Dir.pwd, format: :yml, name: _class_s)
      file_name = name || SecureRandom.hex(6)
      path = "#{path}/#{file_name}.#{format}".pathify
      case format
      when :yaml, :yml
        serialize.to_yaml.to_file(path, mode: 'w')
      when :json
        serialize.to_json.to_file(path, mode: 'w')
      end
      path
    end

    def self.load(data, parent: nil, namespace: TaskVault)
      return data if data.is_a?(self)
      if data.is_a?(String)
        if data.end_with?('.yml', '.yaml')
          data = YAML.load_file(data)
        elsif data.end_with?('.json')
          data = JSON.parse(File.read(data))
        end
      end
      raise ArgumentError, "Failed to load task from '#{path}'." if data.nil?
      data.keys_to_sym!(recursive: false)
      data[:parent] = parent
      klass = data[:class].to_s
      obj = namespace.constants.include?(klass.to_sym) ? namespace : Object
      unless obj.const_get(klass).ancestors.any? { |a| a == self }
        raise "Invalid class #{klass}. Must be a subclass of #{self}."
      end
      obj.const_get(klass).new(data)
    end

    def history_msgs
      @history.map { |h| h[:msg] }
    end

    def event_handlers=(handlers)
      @event_handlers = {}
      handlers.each do |k, v|
        event_handlers[k] = [v].flatten
      end
      event_handlers
    end

    def remove_event_handler(handler)
      @event_handlers.delete(handler)
    end

    def event_handled?(event)
      event_handlers.any? { |_h, e| e.include?(event) }
    end

    protected

    def lazy_setup
      @parent        = nil
      @thread        = nil
      @started       = nil
      @stopped       = nil
      @handlers      = [:default]
      @message_queue = []
      @history       = []
      setup_defaults
      serialize_method :class, :_class_s, always: true
    end

    def setup_defaults
      # Reserved for child classes to setup their own default variables/methods
    end

    def lazy_init(*args)
      named = BBLib.named_args(*args)
      init_thread if named[:start]
      # extend PutsQueue unless named.include?(:no_puts)
    end

    def init_thread
      # This method creates a thread and calls the run method within it.
      # Redefine the run method to have this actually do something.
      @thread = Thread.new do
        begin
          run
        rescue => e
          queue_fatal(e)
        end
      end
    end

    def run
      queue_warn('Uh oh, no one redefined me!')
    end

    def self.validate_handlers(handlers)
      handlers.flatten.flat_map do |handler|
        if handler.is_a?(Hash) || handler.is_a?(Symbol)
          handler
        elsif handler.is_a?(MessageHandler)
          handler.serialize
        else
          handler.to_s.to_sym
        end
      end.uniq
    end

    def register_handlers
      attrs.find_all { |n, o| o[:type] == :handler }.map(&:first).each do |method|
        handlers = send(method) rescue nil
        next if handlers.nil? || handlers.empty?
        replace = handlers.flat_map do |handler|
          register_handler(handler)
        end
        instance_variable_set("@#{method}", replace.uniq)
      end
    end

    def register_event_handlers
      return unless root
      @event_handlers = event_handlers.map do |handler, events|
        if handler.is_a?(Symbol)
          [handler, events]
        else
          [[register_handler(handler)].flatten(1).first, events]
        end
      end
    end

    def register_handler(handler)
      return handler unless root
      if handler.is_a?(Hash) || handler.is_a?(MessageHandler)
        root.components_of(Courier).map do |courier|
          courier.add(handler)
        end
      else
        handler.to_s.to_sym
      end
    end

    def pick_handlers(data)
      if data.include?(:handlers)
        data[:handlers]
      elsif data.include?(:event)
        h = event_handlers.find_all { |_h, e| e && e.include?(data[:event]) }.map(&:first)
        h.empty? ? handlers : h
      else
        handlers
      end
    end

    def hide_on_inspect
      [:@parent, :@thread]
    end

    def compile_msg_data(**data)
      data.merge(time: Time.now, component: self.class.to_s, name: name).merge(msg_metadata).merge(metadata)
    end

    def msg_metadata
      # Have this return a hash. This is always merged with message payloads
      # whenever queue_msg is called.
      {}
    end

    def _class_s
      self.class.to_s
    end
  end
end
