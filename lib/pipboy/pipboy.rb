require 'socket'

class TaskVault

  class Pipboy < Ava::Client

    def health
      self.task_vault.health
    end

    def status
      self.task_vault.status
    end

    def task_list *args
      self.vault.task_list(*args)
    end

    def task id
      self.vault.retrieve(id)
    end

    def queue task
      self.vault.queue(task)
    end

    def add_handler mh, overwrite = true
      self.courier.add_handler(mh, overwrite)
    end

  end

end
