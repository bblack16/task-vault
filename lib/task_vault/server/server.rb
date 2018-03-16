module TaskVault
  class Server
    include BBLib::Effortless
    include BBLib::Prototype

    attr_dir :path, mkdir: true, allow_nil: true, default: File.expand_path('/task_vault', Dir.pwd)
    attr_ary_of Object, :components, default_proc: :_default_components, add_rem: true, adder_name: 'add', remover_name: 'remove'

    after :components=, :add, :register_components
    before :components=, :remove, :unregister_components, send_args: true

    def start(delay = 0.1)
      components.all? do |component|
        component.start
        sleep(delay)
      end
    end

    def stop(delay = 0.1)
      components.reverse.all? do |component|
        component.stop
        sleep(delay)
      end
    end

    def restart
      stop && start
    end

    def self.reboot!(delay = 0)
      Thread.new {
        sleep(delay)
        BBLib.restart
      }
      true
    end

    def running?
      components.any?(&:running?)
    end

    def healthy?
      components.all?(&:running?)
    end

    def in(time, opts = {}, &block)
      if block
        opts[:type] = :proc
        opts[:proc] = block
      end
      Task.new(opts.merge(start_at: Time.now + time))
    end

    def after

    end

    def now(opts = {}, &block)

    end

    def at(time, opts = {}, &block)

    end

    def every(time, opts = {}, &block)

    end

    def cron(time, opts = {}, &block)

    end

    protected

    def simple_init(*args)
      start if BBLib.named_args(*args)[:start]
    end

    def _default_components
      [Overseer.prototype, Courier.prototype]
    end

    def register_components
      components.each { |component| component.register_to(self) }
    end

    def unregister_components(components)
      [components].flatten.each(&:unregister)
    end
  end
end
