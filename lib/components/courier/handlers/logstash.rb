# frozen_string_literal: true
# require 'logstash-logger'

module TaskVault
  module Handlers
    class Logstash < MessageHandler
      TYPES = [:tcp, :upd, :file, :unix, :syslog, :redis, :kafka, :stdout, :stderr, :io]

      attr_bool :message_only, default: true, serialize: true
      attr_ary_of String, :host, default: 'localhost', serialize: true
      attr_int :port, default: 1234, serialize: true
      attr_ary_of [String, Symbol], :include_fields, :exclude_fields, default: nil, allow_nil: true, serialize: true
      attr_element_of TYPES, :type, default: :tcp, serialize: true
      attr_hash :options, default: {}, serialize: true
      attr_reader :logger

      component_aliases(:logstash, :logstash_logger)

      protected

      def run
        setup_logger
        super
      end

      def process_message
        msg = read
        case msg[:severity]
        when :info, :debug, :error, :warn
          logger.send(msg[:severity], build_msg(msg))
        else
          logger.info(build_msg(msg))
        end
      rescue => e
        queue_msg("There was an error processing a message. message = #{msg.to_s[0..49]}..., error = #{e}; #{e.backtrace}", severity: :error)
      end

      def build_msg(msg)
        if exclude_fields.nil? && include_fields
          msg = msg.reject { |k, v| !include_fields.include?(k) }
        elsif exclude_fields
          msg = msg.reject { |k, v| exclude_fields.include?(k) && (include_fields.nil? || include_fields.include?(k)) }
        end
        msg
      end

      def setup_logger
        @logger = LogStashLogger.new(options.merge(host: host, port: port))
      rescue => e
        queue_msg("Error creating LogStashLogger: #{e}; #{e.backtrace.join('; ')}", severity: :fatal)
      end
    end
  end
end
