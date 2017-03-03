# frozen_string_literal: true
require 'bunny'

module TaskVault
  module Handlers
    class RabbitMQ < MessageHandler
      attr_bool :message_only, default: true, serialize: true
      attr_ary_of String, :host, default: 'localhost', serialize: true
      attr_int :port, default: 5672, serialize: true
      attr_str :user, :pass, default: 'guest', serialize: true
      attr_str :default_queue, default: nil, allow_nil: true, serialize: true
      attr_bool :keep_alive, default: true, serialize: true
      attr_element_of [:json, :yaml, :string], :format, default: :json, serialize: true
      attr_ary_of [String, Symbol], :include_fields, :exclude_fields, default: nil, allow_nil: true, serialize: true
      attr_reader :connection, :channel

      add_alias(:rabbitmq, :rabbit_mq)

      protected

      def run
        setup_connection
        super
      end

      def process_message
        open_channel
        msg   = read
        queue = get_queue(msg[:queue] || default_queue)
        channel.default_exchange.publish(build_msg(msg), routing_key: queue.name)
      rescue => e
        queue_msg("There was an error processing a message. message = #{msg.to_s[0..49]}..., error = #{e}; #{e.backtrace}", severity: :error)
      end

      def build_msg(msg)
        if exclude_fields.nil? && include_fields
          msg = msg.reject { |k, v| !include_fields.include?(k) }
        elsif exclude_fields
          msg = msg.reject { |k, v| exclude_fields.include?(k) && (include_fields.nil? || include_fields.include?(k)) }
        end
        case format
        when :json
          msg.to_json
        when :yaml
          msg.to_yaml
        else
          msg.to_s
        end
      end

      def setup_connection
        @connection = Bunny.new(host: host, port: port, user: user, pass: pass)
        @connection.start
      rescue => e
        queue_msg("Error creating Bunny connection: #{e}; #{e.backtrace.join('; ')}", severity: :fatal)
      end

      def open_channel
        return if @channel && @channel.open?
        setup_connection unless @connection
        @channel = @connection.create_channel
      rescue => e
        queue_msg("Error opening channel: #{e}; #{e.backtrace.join('; ')}", severity: :error)
      end

      def close_channel
        @channel.close
      rescue => e
        queue_msg("Error closing channel: #{e}; #{e.backtrace.join('; ')}", severity: :error)
      end

      def get_queue(name)
        @channel.queue(name)
      end
    end
  end
end
