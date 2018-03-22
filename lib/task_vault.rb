require 'bblib' unless defined?(BBLib::VERSION)
require 'securerandom'

require_relative 'task_vault/version'

require_relative 'task_vault/puts_override'
require_relative 'task_vault/runnable'

require_relative 'task_vault/task'
require_relative 'task_vault/components/overseer'
require_relative 'task_vault/components/courier'
require_relative 'task_vault/components/workbench'
require_relative 'task_vault/server'

BBLib.scan_files(File.expand_path('../task_vault/tasks', __FILE__), '*.rb') do |file|
  require_relative file
end

BBLib.scan_files(File.expand_path('../task_vault/specialty_tasks', __FILE__), '*.rb') do |file|
  require_relative file
end
