require_relative "component"
require_relative "task/task"
require_relative "vault/vault"
require_relative "workbench/workbench"
require_relative "protectron/protectron"
require_relative "courier/courier"
require_relative "overworld/overworld"

class TaskVault
  attr_reader :cfg_policy, :path, :vault, :workbench, :protectron, :courier, :overworld

  def initialize path = Dir.pwd, start: false
    @vault = Vault.new
    @workbench = Workbench.new(self)
    @courier = Courier.new(self)
    @overworld = Overworld.new(self)
    @protectron = Protectron.new self
    self.start if start
  end

  def path= path
    @path = path.to_s
    @vault.path = @path
    @workbench.path = @path
  end

  def start
    @vault.start
    @courier.start
    @workbench.start
    @overworld.start
    @protectron.start
  end

  def stop
    @protectron.stop
    @overworld.stop
    @workbench.stop
    @vault.stop
    @courier.stop
  end

  def restart
    @vault.restart
    @workbench.restart
    @courier.restart
    @overworld.restart
    @protectron.restart
  end

end
