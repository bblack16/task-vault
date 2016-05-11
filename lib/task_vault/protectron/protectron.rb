class TaskVault

  class Protectron < Component
    attr_reader :interval, :thread

    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    protected

      def setup_defaults
        self.interval = 60
      end

      def init_thread
        @thread = Thread.new {
          begin
            loop do
              start = Time.now.to_f
              info = {checked:0, errors: 0, success:0, failed:0}
              queue_msg "Protectron is commencing check of components...Initial State: #{@parent.health}", severity: 7

              [@parent.vault, @parent.workbench, @parent.courier, @parent.sentry].each do |obj|
                info[:checked]+=1
                if !obj.running?
                  puts "WARN - Protectron found '#{obj.class}' in an inactive state. Attempting to restart now..."
                  queue_msg "Protectron found '#{obj.class}' in an inactive state. Attempting to restart now...", severity: 3
                  info[:errors]+=1
                  obj.restart
                  sleep(0.5)
                  if obj.running?
                    queue_msg "Protectron successfully restarted #{obj.class}!", severity: 5
                    info[:success]+=1
                  else
                    queue_msg "Protectron was unable to restart #{obj.class}.", severity: 2
                    info[:failed]+=1
                  end
                end
              end

              queue_msg("Protectron finished checking #{info[:checked]} (final state: #{@parent.health}) components and found #{info[:errors]} errors.#{info[:errors] > 0 ? " Protectron was able to successfully fix #{info[:success]} and failed to fix #{info[:failed]} components." : nil}", severity: (info[:errors] > 0 ? 3 : 5))
              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            queue_msg(e, severity: 2)
            e
          end
        }
      end

  end

end
