module TaskVault

  def self.method_missing(method, *args, &block)
    if TaskVault::Server.prototype.respond_to?(method)
      TaskVault::Server.prototype.send(method, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_private = false)
    TaskVault::Server.prototype.respond_to?(method) || super
  end

  class Server
    include BBLib::Effortless
    include BBLib::Prototype

    attr_dir :path, mkdir: true, allow_nil: true, default: TaskVault.default_path
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

    def component_of(klass)
      components.find { |component| component.is_a?(klass) }
    end

    def running?
      components.any?(&:running?)
    end

    def healthy?
      components.all?(&:running?)
    end

    def queue(task, &block)
      start unless running?
      overseer = components.find { |component| component.is_a?(Overseer) }
      return false unless overseer
      overseer.add(task, &block)
    end

    def create_task(opts = {}, &block)
      opts[:type] = :proc if block
      opts[:proc] = block if block
      Task.new(opts)
    end

    def in(time, opts = {}, &block)
      queue(create_task(opts.merge(start_time: Time.now + time), &block))
    end

    def after(time, opts = {}, &block)
      queue(create_task(opts.merge(repeat: "after #{time}s"), &block))
    end

    def now(opts = {}, &block)
      queue(create_task(opts.merge(start_time: Time.now), &block))
    end

    def at(time, opts = {}, &block)
      queue(create_task(opts.merge(start_time: time), &block))
    end

    def every(time, opts = {}, &block)
      queue(create_task(opts.merge(repeat: "every #{time}s"), &block))
    end

    def cron(time, opts = {}, &block)
      queue(create_task(opts.merge(repeat: time), &block))
    end

    protected

    def simple_init(*args)
      start if BBLib.named_args(*args)[:start]
    end

    def _default_components
      [Overseer.prototype, Courier.prototype, Workbench.prototype]
    end

    def register_components
      components.each { |component| component.register_to(self) }
    end

    def unregister_components(components)
      [components].flatten.each(&:unregister)
    end
  end
end
