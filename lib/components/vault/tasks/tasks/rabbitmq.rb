# frozen_string_literal: true
module TaskVault
  module Tasks
    class RabbitMQ < Task
      attr_str :queue, default: :task_vault, serialize: true
      attr_hash :options, default: { block: true }, serialize: true
      attr_int :prefetch, default: nil, allow_nil: true, serialize: true
      attr_of Bunny, :connection, serialize: false
      attr_reader :channel, serialize: false

      component_aliases(:rabbitmq, :rabbit_mq)

      protected

      # Redefine this method in subclasses. The default version just queues the message in TaskVault
      def process_message(msg, info, properties)
        queue_data(msg, event: :message, info: info, properties: properties)
        # Remeber to ack the message if manual_ack is used
        acknowledge(delivery_info.delivery_tag) if options[:manual_ack]
      end

      def run
        queue_debug('Setting everything up and opening channel...')
        open_channel
        get_queue.subscribe(options) do |delivery_info, properties, body|
          process_message(body, delivery_info, properties)
        end
      end

      def acknowledge(id)
        channel.acknowledge(id, false)
      end

      def open_channel
        return if @channel && @channel.open? || @connection.nil?
        @channel = @connection.create_channel
        @channel.prefetch(prefetch) if prefetch
      rescue => e
        queue_error(e)
      end

      def close_channel
        @channel.close
      rescue => e
        queue_error(e)
      end

      def get_queue
        @channel.queue(queue)
      end
    end
  end
end
