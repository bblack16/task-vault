module TaskVault

  class Component < BBLib::LazyClass
    attr_of Object, :parent, allow_nil: true
    attr_array_of Symbol, :handlers, raise: true, serialize: true, always: true
    attr_int_between 0, nil, :history_limit, default: 100, serialize: true, always: true
    attr_int_between 0, nil, :message_limit, default: 100000, serialize: true, always: true
    attr_reader :message_queue, :thread, :started, :stopped, :history

    def start
      init_thread unless running?
      @started = Time.now
      running?
    end

    def stop
      @stopped = Time.now if running?
      @thread.kill if @thread
      sleep(0.2)
      !running?
    end

    def restart
      stop && start
    end

    def running?
      !@thread.nil? && @thread.alive?
    end

    def uptime
      return 0 if @started.nil?
      running? ? Time.now - @started : 0
    end

    def queue_msg msg, **data
      msg = {
          msg:      msg,
          handlers: @handlers,
          severity: (msg.is_a?(Exception) ? :error : :info)
        }.merge(compile_msg_data(**data))
      @history.unshift(msg.dup)
      while @history.size > @history_limit
        @history.pop
      end
      @message_queue.push(msg)
      while @message_queue.size > @message_limit
        @message_queue.shift
      end
    end

    alias_method :queue_message, :queue_msg

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
      @message_queue.size > 0
    end

    # Custom inspect to able to hide unwanted variables or pointers
    def inspect
      vars = self.instance_variables.map do |v|
        "#{v}=#{instance_variable_get(v).inspect}" unless hide_on_inspect.include?(v)
      end.reject(&:nil?).join(", ")
      "<#{self.class}:0x#{self.object_id} #{vars}>"
    end

    def save path = Dir.pwd, format: :yml, name: _class_s
      file_name = name || SecureRandom.hex(6);
      path = "#{path}/#{file_name}.#{format.to_s}".pathify
      case format
      when :yaml, :yml
        serialize.to_yaml.to_file(path, mode: 'w')
      when :json
        serialize.to_json.to_file(path, mode: 'w')
      end
      path
    end

    def self.load data, parent: nil
      return data if data.is_a?(self)
      if data.is_a?(String)
        if data.end_with?('.yml') || data.end_with?('.yaml')
          data = YMAL.load_file(data)
        elsif data.end_with?('.json')
          data = JSON.parse(File.read(data))
        end
      end
      raise ArgumentError, "Failed to load task from '#{path}'." if data.nil?
      data.keys_to_sym!
      data[:parent] = parent
      klass = data[:class].to_s
      obj = TaskVault.constants.include?(klass.to_sym) ? TaskVault : Object
      unless obj.const_get(klass).ancestors.any?{ |a| a == self }
        raise "Invalid class #{klass}. Must be a subclass of #{self}."
      end
      obj.const_get(klass).new(data)
    end

    def history_msgs
      @history.map{ |h| h[:msg] }
    end

    protected

    def lazy_setup
      @parent        = nil
      @thread        = nil
      @started       = nil
      @stopped       = nil
      @handlers      = [:default]
      @message_queue = Array.new
      @history       = Array.new
      setup_defaults
      serialize_method :class, :_class_s, always: true
    end

    def setup_defaults
      # Reserved for child classes to setup their own default variables/methods
    end

    def custom_lazy_init *args
      named = BBLib.named_args(*args)
      init_thread if named[:start]
      extend PutsQueue unless named.include?(:no_puts)
    end

    def init_thread
      # This method creates a thread and calls the run method within it.
      # Redefine the run method to have this actually do something.
      @thread = Thread.new{
        begin
          self.run
        rescue StandardError, Exception => e
          queue_msg("#{e}: #{e.backtrace}", severity: :fatal)
        end
      }
    end

    def run
      puts 'Uh oh, no one redefined me!', severity: :warn
    end

    def hide_on_inspect
      [ :@parent, :@thread ]
    end

    def compile_msg_data **data
      data.merge(time: Time.now, component: self.class.to_s).merge(msg_metadata)
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
