require 'bblib' unless defined?(BBLib::VERSION)
require 'securerandom'

require_relative 'task_vault/version'
require_relative 'task_vault/util'
require_relative 'task_vault/puts_override'
require_relative 'task_vault/runnable'
require_relative 'task_vault/task'
require_relative 'task_vault/components/overseer'
require_relative 'task_vault/components/courier'
require_relative 'task_vault/components/workbench'
require_relative 'task_vault/server'

require_relative 'task_vault/tasks/cmd'
require_relative 'task_vault/tasks/eval'
require_relative 'task_vault/tasks/proc'
require_relative 'task_vault/tasks/watch_folder'

require_relative 'task_vault/specialty_tasks/hand_brake_watch_folder'
