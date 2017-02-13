# frozen_string_literal: true
require_relative 'task_vault/version'

require 'bblib' unless defined?(BBLib::VERSION)
require 'ava' unless defined?(Ava::VERSION)
require 'yaml'
require 'json'
require 'sinatra'

require_relative 'components/_components'
require_relative 'server/server'

module TaskVault
end
