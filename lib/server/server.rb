# frozen_string_literal: true
module TaskVault
  class Server < BBLib::LazyClass
    attr_valid_dir :path, allow_nil: true, default: Dir.pwd, serialize: true, always: true
    attr_hash :components, serialize: true, always: true

    def path=(path)
      @path = path
      @components.each do |_n, c|
        c.path = path if c.respond_to?(:path=)
      end
    end

    def start(delay = 0.1)
      @components.all? do |_n, c|
        c.start
        sleep(delay)
      end
    end

    def stop(delay = 0.1, complete: false)
      @components.reverse.all? do |n, c|
        next if !complete && n == :overseer
        c.stop
        sleep(delay)
      end
    end

    def restart
      @components.all? { |_n, c| c.restart }
    end

    def set_handlers(*handlers)
      @components.map { |n, c| [n, c.handlers = handlers] }.to_h
    end

    def running?
      @components.any? { |_n, c| c.running? }
    end

    def healthy?
      @components.all? { |_n, c| c.running? }
    end

    def add(components)
      components.each do |name, component|
        raise ArgumentError, "Values must be descendants of TaskVault::Component not #{component.class}" unless component.is_a?(TaskVault::Component)
        component.parent = self
        component.name = name
        @components[name.to_sym] = component
      end
    end

    def remove(*components)
      components.each { |name| @components.delete(name.to_sym) }
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
        ip_address:  ip_address,
        config_path: path,
        working_dir: Dir.pwd,
        time:        server_time,
        running:     running?,
        components:  @components.map { |n, c| [n, { running: c.running?, uptime: c.uptime, class: c.class }] }.to_h
        # handlers:    courier.message_handlers.map { |n, h| [n, { running: h.running?, uptime: h.uptime }] }.to_h
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
      if component = @components.find { |n, _c| n == args.first }
        component[1]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @components.find { |n, _c| n == method } || super
    end

    protected

    def lazy_setup
      @components = {}
      add(
        courier:   Courier.new(parent: self, name: 'courier'),
        vault:     Vault.new(parent: self, name: 'vault'),
        workbench: Workbench.new(parent: self, name: 'workbench'),
        sentry:    Sentry.new(parent: self, name: 'sentry'),
        radio:     Radio.new(parent: self, name: 'radio')
      )
    end

    def lazy_init(*args)
      named = BBLib.named_args(*args)
      [named[:remove]].flatten.each { |n| remove(n) } if named[:remove]
      start if named[:start]
    end
  end
end
