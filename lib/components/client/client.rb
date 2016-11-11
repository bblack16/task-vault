# frozen_string_literal: true
module TaskVault
  class Client < Ava::Client
    PRESETS = {
      health:          :server,
      status:          :server,
      start:           :server,
      stop:            :server,
      restart:         :server,
      running?:        :server,
      set_handlers:    :server,
      ip_address:      :server,
      server_time:     :server,
      add_task:        :vault,
      task:            :vault,
      cancel:          :vault,
      task_list:       :vault,
      add_recipe:      :workbench,
      add_msg_handler: :courier
    }.freeze

    def method_missing(*args)
      if preset = PRESETS[args.first]
        send(preset).tcr.send(*args)._s
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      PRESETS.include?(method) || super
    end
  end
end
