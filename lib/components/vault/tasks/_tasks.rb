require_relative 'task'
require_relative 'tasks/cmd_task'
require_relative 'tasks/script_dir'
require_relative 'tasks/watch_folder'
require_relative 'tasks/eval_task'
require_relative 'tasks/proc_task'
require_relative 'tasks/sysmon'
require_relative 'tasks/rabbitmq' if defined?(Bunny)
require_relative 'tasks/mongo' if defined?(Mongo)
require_relative 'tasks/elasticsearch' if defined?(RestClient)
require_relative 'tasks/rest' if defined?(RestClient)
require_relative 'tasks/sql' if defined?(Sequel)
