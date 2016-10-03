
module TaskVault

  class Client < Ava::Client

    PRESETS = {
      health:          :overseer,
      status:          :overseer,
      start:           :overseer,
      stop:            :overseer,
      restart:         :overseer,
      running?:        :overseer,
      set_handlers:    :overseer,
      ip_address:      :overseer,
      server_time:     :overseer,
      add_task:        :vault,
      task:            :vault,
      cancel:          :vault,
      task_list:       :vault,
      add_recipe:      :workbench,
      add_msg_handler: :courier
    }

    def method_missing *args
      if preset = PRESETS[args.first]
        self.send(preset).tcr.send(*args)._s
      else
        super
      end
    end

  end

end
