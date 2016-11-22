# frozen_string_literal: true
module TaskVault
  class Sentry < Component
    attr_float_between 0.001, nil, :interval, default: 60, serialize: true, always: true
    attr_float_between 0, nil, :initial_delay, default: 60, serialize: true, always: true
    attr_array_of String, :components, default: [], add_rem: true, serialize: true, always: true
    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      super
    end

    def self.description
      'No component left behind, that is Sentry\'s motto. Sentry checks other components on an interval to ' \
      'ensure they are running. If a component is down, Sentry will attempt to restart it.'
    end

    protected

    def run
      sleep(@initial_delay)
      loop do
        start = Time.now
        info = { checked: 0, errors: 0, success: 0, failed: 0 }
        queue_msg("Sentry is commencing a check of all components. Initial state: #{@parent.health}", severity: :debug)
        @parent.components.each do |name, component|
          next unless @components.empty? || @components.include?(name)
          info[:checked] += 1
          next if component.running?
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

        sleep_time = @interval - (Time.now.to_f - start.to_f)
        queue_msg(
          "Sentry finished checking #{info[:checked]} components. Final state: #{@parent.health}." +
          (info[:errors].positive? ? " There were errors with #{info[:errors]} component#{info[:errors] > 1 ? 's:' : nil} #{info[:success]} were successfully restarted, #{info[:failed]} failed to restart." : '') +
          " Next run is in #{sleep_time.to_duration}.",
          severity: (info[:errors] && info[:failed].positive? ? :error : (info[:errors].positive? ? :warn : :info))
        )
        sleep(sleep_time.negative? ? 0 : sleep_time)
      end
    end
  end
end
