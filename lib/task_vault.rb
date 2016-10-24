require_relative "task_vault/version"

require 'bblib' unless defined?(BBLib::VERSION)
require 'ava' unless defined?(Ava::VERSION)
require 'yaml'
require 'json'

require_relative 'components/_components'
require_relative 'tasks/_tasks'

module TaskVault

  def self.registry
    @@registry ||= Array.new
  end

  singleton_class.send(:alias_method, :task_types, :registry)

  def self.load_registry *namespaces
    registry.clear
    namespaces = [TaskVault] if namespaces.empty?
    namespaces.each do |namespace|
      namespace.constants.each do |constant|
        constant = namespace.const_get(constant.to_s)
        next if constant == TaskVault::Task
        if constant.respond_to?(:is_task_vault_task?) && constant.is_task_vault_task?
          registry.push(constant) unless registry.include?(constant)
        end
      end
    end
    registry
  end

end

TaskVault.load_registry
