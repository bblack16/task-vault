# frozen_string_literal: true
module TaskVault
  module Tasks
    class Spawner < Task
      attr_hash :template, default: {}, serialize: true, always: true, to_serialize_only: true
      attr_ary_of [String, Symbol], :allowed, :banned, default: nil, allow_nil: true, serialize: true, always: true
      attr_str :base_name, default: 'spawn_', serialize: true, always: true
      attr_int :counter, default: 0, serialize: false

      component_aliases(:spawner)

      protected

      def run
        queue_debug('Spawner, reporting for duty.')
        loop do
          sleep(5)
        end
      end

      def launch_task(payload = {})
        task = parent.add(sanitize(payload))
        self.counter += 1
        task
      end

      def sanitize(payload)
        payload = payload.only(*allowed) if allowed
        payload = payload.except(*banned) if banned
        payload[:name] = name_gen unless payload[:name]
        queue_debug("Spawning new task '#{payload[:name]}' from: #{BBLib.chars_up_to(payload, 50)}")
        payload = template.dup.merge(payload)
        payload
      end

      def name_gen
        "#{base_name}#{counter}"
      end

      def setup_routes
        get '/template' do
          template
        end

        post '/' do
          begin
            task = launch_task(JSON.parse(request.body.read).keys_to_sym)
            { status: 200, message: "Added task #{task.name} (#{task.id}) to vault." }
          rescue => e
            { status: 500, message: "Failed to launch new task: #{e}" }
          end
        end
      end
    end
  end
end
