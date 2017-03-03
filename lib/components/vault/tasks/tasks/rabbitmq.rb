# frozen_string_literal: true
module TaskVault
  module Tasks
    class RabbitMQ < Task
      attr_ary_of String, :host, default: 'localhost', serialize: true
      attr_int :port, default: 5672, serialize: true
      attr_str :user, :pass, default: 'guest', serialize: true
      attr_str :queue, default: :task_vault, serialize: true
      attr_hash :options, default: { block: true }, serialize: true
      attr_int :prefetch, default: nil, allow_nil: true, serialize: true
      attr_reader :connection, :channel

      add_alias(:rabbitmq, :rabbit_mq)

      protected

      # Redefine this method. The default version just queues the message in TaskVault
      def process_message(msg, info, properties)
        queue_msg(msg, severity: :info)
        # Remeber to ack the message if manual_ack is used
        acknowledge(delivery_info.delivery_tag) if options[:manual_ack]
      end

      def run
        queue_msg('Setting everything up...', severity: :debug)
        open_channel
        get_queue.subscribe(options) do |delivery_info, properties, body|
          process_message(body, delivery_info, properties)
        end
      end

      def acknowledge(id)

      end

      def setup_connection
        @connection = Bunny.new(host: host, port: port, user: user, pass: pass)
        @connection.start
      rescue => e
        queue_msg("Error creating Bunny connection to #{host}: #{e}; #{e.backtrace.join('; ')}", severity: :fatal)
      end

      def open_channel
        return if @channel && @channel.open?
        setup_connection unless @connection
        @channel = @connection.create_channel
        @channel.prefetch(prefetch) if prefetch
      rescue => e
        queue_msg("Error opening channel: #{e}; #{e.backtrace.join('; ')}", severity: :error)
      end

      def close_channel
        @channel.close
      rescue => e
        queue_msg("Error closing channel: #{e}; #{e.backtrace.join('; ')}", severity: :error)
      end

      def get_queue
        @channel.queue(queue)
      end
    end
  end
end
