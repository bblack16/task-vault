module TaskVault

  def self.default_path
    ENV['TASK_VAULT_HOME'] || File.join(Dir.home, '.task-vault')
  end
  
end
