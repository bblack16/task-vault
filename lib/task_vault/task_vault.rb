require_relative "component"
require_relative "task/task"
require_relative "task/_tasks"
require_relative "vault/vault"
require_relative "workbench/workbench"
require_relative "protectron/protectron"
require_relative "courier/courier"
require_relative "sentry/sentry"

class TaskVault
  attr_reader :path, :vault, :workbench, :protectron, :courier, :sentry

  def initialize path: Dir.pwd, start: false, key: 'bobblehead', port: 2016
    @vault = Vault.new(self)
    @workbench = Workbench.new(self)
    @courier = Courier.new(self)
    @sentry = Sentry.new(self, key: key, port: port)
    @protectron = Protectron.new(self)
    self.path = path
    self.start if start
  end

  def path= path
    path = (path + (path.end_with?('/taskvault') ? '' : '/taskvault/')).pathify unless path.nil?
    @path = path
    @vault.path = @path
    @workbench.path = @path
    @courier.path = "#{@path}/message_handlers".pathify
  end

  def start
    @vault.start
    @courier.start
    @workbench.start
    @sentry.start
    @protectron.start
    running?
  end

  def stop complete = false
    @protectron.stop
    @workbench.stop
    @vault.stop
    sleep(1) # Hack to let courier keep processing. This will be replaced with something better.
    @courier.stop
    @sentry.stop if complete
    !running?
  end

  def restart
    @vault.restart
    @workbench.restart
    @courier.restart
    @sentry.restart
    @protectron.restart
    running?
  end

  def change_handlers *handlers
    [@vault, @workbench, @courier, @sentry, @protectron].each{ |obj| obj.message_handlers = handlers }
    true
  end

  def running?
    @vault.running? && @workbench.running? && @courier.running? && @protectron.running? && @sentry.running?
  end

  def health
    if running?
      :green
    elsif @vault.running? || @workbench.running? || @courier.running?
      :yellow
    else
      :red
    end
  end

  def status
    {
      ip_address: ip_address,
      health: health,
      components: component_status,
      time: server_time,
      running: running?
    }
  end

  def component_status
    {
      vault: {running: @vault.running?, uptime: @vault.uptime},
      workbench: {running: @workbench.running?, uptime: @workbench.uptime},
      courier: {running: @courier.running?, uptime: @courier.uptime},
      protectron: {running: @protectron.running?, uptime: @protectron.uptime},
      sentry: {running: @sentry.running?, uptime: @sentry.uptime},
      message_handlers: @courier.handlers.map{ |h| [h.name, {running: h.running?, uptime: h.uptime}]}.to_h
    }
  end

  def ip_address version = 4
    ips = Socket.ip_address_list.map{ |i| i.ip_address }
    case version
    when 4 || :v4 || :ipv4
      ips.reject!{|r| !(r =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) || r == '127.0.0.1'}
    when 6 || :v6 || :ipv6
      ips.reject!{|r| (r =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) || r == '::1'}
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

end
