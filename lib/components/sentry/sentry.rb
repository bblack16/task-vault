module TaskVault

  class Sentry < Component
    attr_float_between 0.001, nil, :interval, default: 60

    def start
      queue_msg("Starting up component.", severity: :info)
      super
    end

    def stop
      queue_msg("Stopping component.", severity: :info)
      super
    end

    protected

      def run
        loop do
          sleep(5)
          start = Time.now
          info = { checked: 0, errors: 0, success: 0, failed: 0 }
          queue_msg("Sentry is commencing a check of all components. Initial state: #{@parent.health}", severity: :debug)
          [@parent.components, @parent.courier.message_handlers].each do |component_set|
            component_set.each do |name, component|
              info[:checked] += 1
              unless component.running?
                queue_msg("Sentry found #{name} in an inactive state. Attempting to restart it now.", severity: :warn)
                info[:errors] += 1
                component.restart
                sleep(0.5)
                if component.running?
                  queue_msg("Sentry successfully restarted #{name}.", severity: :warn)
                  info[:success] += 1
                else
                  queue_msg("Sentry was unable to restart #{name}.", severity: :error)
                  info[:failed] += 1
                end
              end
            end
          end

          sleep_time = @interval - (Time.now.to_f - start.to_f)
          queue_msg(
          "Sentry finished checking #{info[:checked]} components. Final state: #{@parent.health}." +
          (info[:errors] > 0 ? " There were errors with #{info[:errors]} component#{info[:errors] > 1 ? 's:' : nil} #{info[:success]} were successfully restarted, #{info[:failed]} failed to restart." : '' ) +
          " Next run is in #{sleep_time.to_duration}.",
          severity: (info[:errors] && info[:failed] > 0 ? :error : ( info[:errors] > 0 ? :warn : :info ) )
          )
          sleep(sleep_time < 0 ? 0 : sleep_time)
        end
      end

  end

end