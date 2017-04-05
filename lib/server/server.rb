# frozen_string_literal: true
module TaskVault
  class Server < BBLib::LazyClass
    attr_valid_dir :path, mkdir: true, allow_nil: true, default: Dir.pwd, serialize: true, always: true
    attr_ary_of ServerComponent, :components, default: [], serialize: true, always: true

    def path=(path)
      @path = path
      @components.each do |c|
        c.path = path if c.respond_to?(:path=)
      end
    end

    def start(delay = 0.1)
      @components.all? do |c|
        c.start
        sleep(delay)
      end
    end

    def stop(delay = 0.1)
      @components.reverse.all? do |c|
        c.stop
        sleep(delay)
      end
    end

    def restart
      @components.all?(&:restart)
    end

    def self.reboot(delay = 0)
      Thread.new {
        sleep(delay)
        BBLib.restart
      }
      true
    end

    def set_handlers(*handlers)
      @components.map { |c| [c.name, c.handlers = handlers] }.to_h
    end

    def running?
      @components.any?(&:running?)
    end

    def healthy?
      @components.all?(&:running?)
    end

    def add(*components)
      components.each do |component|
        component = Component.load(component) if component.is_a?(Hash)
        raise ArgumentError, "Values must be descendants of TaskVault::Component not #{component.class}" unless component.is_a?(TaskVault::ServerComponent)
        component.parent = self
        component.path = path if component.respond_to?(:path=)
        remove(component.name).&stop if component?(component.name)
        @components << component
      end
    end

    def remove(*keys)
      keys.each do |key|
        if key.is_a?(Fixnum)
          componenets[key]
        elsif key.is_a?(ServerComponent)
          next unless components.include?(key)
          key
        else
          component(key)
        end&.disown
      end
    end

    def component(name)
      components.find { |c| c.name == name.to_sym }
    end

    def component?(name)
      components.any? { |c| c.name == name.to_sym }
    end

    def components_of(klass)
      components.find_all { |c| c.class == klass }
    end

    def health
      if healthy?
        :green
      elsif running?
        :yellow
      else
        :red
      end
    end

    def status
      {
        health:      health,
        version:     TaskVault::VERSION,
        hostname:    (`hostname`.chop rescue nil),
        pid:         Process.pid,
        cmdline:     BBLib.cmd_line,
        ip_address:  ip_address,
        config_path: path,
        working_dir: Dir.pwd,
        time:        server_time,
        running:     running?,
        components:  @components.map { |c| [c.name, { running: c.running?, uptime: c.uptime, class: c.class }] }.to_h
      }
    end

    def ip_address(version = 4)
      ips = Socket.ip_address_list.map(&:ip_address)
      case version
      when 4 || :v4 || :ipv4
        ips.reject! { |r| !(r =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) }
      when 6 || :v6 || :ipv6
        ips.reject! { |r| (r =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) }
      when 'all' || :all
        # nada to do
      else
        return nil
      end
      ips
    end

    def server_time
      Time.now
    end

    def method_missing(*args)
      if component = @components.find { |c| c.name == args.first.to_s.to_sym }
        component
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @components.find { |c| c.name == method.to_s.to_sym } || super
    end

    def self.basic(*args)
      TaskVault::Server.new(*args) do |t|
        t.add(
          Courier.new(name: :courier),
          Vault.new(name: :vault),
          Sentry.new(name: :sentry),
          Inventory.new(name: :inventory)
        )
      end
    end

    def self.classic(*args)
      TaskVault::Server.new(*args) do |t|
        t.add(
          Courier.new(name: :courier),
          Vault.new(name: :vault),
          Workbench.new(name: :workbench),
          Sentry.new(name: :sentry),
          Radio.new(name: :radio),
          Inventory.new(name: :inventory)
        )
      end
    end

    def self.complete(*args)
      TaskVault::Server.new(*args) do |t|
        t.add(
          Courier.new(name: :courier),
          Vault.new(name: :vault),
          Workbench.new(name: :workbench),
          Sentry.new(name: :sentry),
          Radio.new(name: :radio),
          Wasteland.new(name: :wasteland),
          Inventory.new(name: :inventory)
        )
      end
    end

    def available_components
      TaskVault::ServerComponent.descendants
    end

    protected

    def lazy_init(*args)
      start if BBLib.named_args(*args)[:start]
    end
  end
end
