# frozen_string_literal: true
require_relative 'task_vault/version'

require 'opal'
require 'opal-jquery'
require 'bblib' unless defined?(BBLib::VERSION)
require 'ava' unless defined?(Ava::VERSION)
require 'dformed' unless defined?(DFormed::VERSION)
require 'yaml'
require 'json'

require_relative 'components/_components'
require_relative 'server/server'
require_relative 'tasks/_tasks'

module TaskVault
  def self.registry
    @@registry ||= { tasks: [], handlers: [] }
  end

  def self.load_registry(*namespaces)
    @@registry = { tasks: [], handlers: [] }
    namespaces = [TaskVault] if namespaces.empty?
    namespaces.each do |namespace|
      namespace.constants.each do |constant|
        constant = namespace.const_get(constant.to_s)
        next if constant == TaskVault::Task
        if constant.respond_to?(:task_vault_task?) && constant.task_vault_task?
          registry[:tasks].push(constant) unless registry[:tasks].include?(constant)
        elsif constant.respond_to?(:is_task_vault_handler?) && constant.is_task_vault_handler?
          registry[:handlers].push(constant) unless registry[:handlers].include?(constant)
        end
      end
    end
    registry
  end
end

TaskVault.load_registry
