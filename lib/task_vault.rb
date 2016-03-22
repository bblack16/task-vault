require_relative "task_vault/version"
require_relative "task_vault/task_vault"

require 'bblib' if !defined?(BBLib::VERSION)


class TaskVault
  include BBLib
end
