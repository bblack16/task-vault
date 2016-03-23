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
              queue_msg "DEBUG - Protectron is commencing check of components..."

              [@parent.vault, @parent.workbench, @parent.courier, @parent.overworld].each do |obj|
                info[:checked]+=1
                if !obj.running?
                  queue_msg "WARN - Protectron found '#{obj.class}' in an inactive state. Attempting to restart now..."
                  info[:errors]+=1
                  obj.restart
                  sleep(0.5)
                  if obj.running?
                    queue_msg "INFO - Protectron successfully restarted #{obj.class}!"
                    info[:success]+=1
                  else
                    queue_msg "ERROR - Protectron was unable to restart #{obj.class}."
                    info[:failed]+=1
                  end
                end
              end

              queue_msg("#{info[:errors] > 0 ? "WARN" : "INFO"} - Protectron finished checking #{info[:checked]} components and found #{info[:errors]} errors.#{info[:errors] > 0 ? " Protectron was able to successfully fix #{info[:success]} and failed to fix #{info[:failed]} components." : nil}")
              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            queue_msg(e)
            e
          end
        }
      end

  end

end
