require 'bblib' unless defined?(BBLib::VERSION)
require 'securerandom'

require_relative 'task_vault/version'

require_relative 'task_vault/general/puts_override'

require_relative 'task_vault/general/runnable'

require_relative 'task_vault/components/task'
require_relative 'task_vault/components/overseer'
require_relative 'task_vault/components/courier'
require_relative 'task_vault/server/server'

BBLib.scan_files(File.expand_path('../task_vault/components/tasks', __FILE__), '*.rb') do |file|
  require_relative file
end
