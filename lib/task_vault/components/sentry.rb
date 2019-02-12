module TaskVault
  class Sentry
    include Runnable
    include BBLib::Prototype

    attr_ary_of String, :components, default: nil, allow_nil: true
    attr_float :restart_pause, default: 0.5

    protected

    def simple_setup
      self.interval = 60
      self.delay = 2
    end

    def run(*args, &block)
      if parent
        info = { total: 0, errors: 0, success: 0, failed: 0 }
        parent.components.each do |component|
          info[:total] += 1
          next if component.running?
          warn("Sentry found #{component.name} in an inactive state. Attempting to restart it now...")
          info[:errors] += 1
          component.restart
          sleep(restart_pause)
          if component.running?
            info("Sentry successfully restarted #{component.name}.")
            info[:sucess] += 1
          else
            warn("Sentry was unable to restart #{component.name}.")
            info[:failed] += 1
          end
        end
        debug("Sentry finished checking #{BBLib.plural_string(info[:total], 'component')}.")
        debug("Sentry was able to successfully restart #{BBLib.plural_string(info[:success], 'component')}")  unless info[:success].zero?
        debug("Sentry was unable to restart #{BBLib.plural_string(info[:failed], 'component')}") unless info[:failed].zero?
      else
        debug("There is no parent set for this sentry. Nothing to do...")
      end
    rescue => e
      error(e)
    end

  end
end
