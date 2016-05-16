

class TaskVault

  class DynamicTask < Task
    attr_reader :interval
    
    def interval= it
      @interval = BBLib::keep_between(it, 0, nil)
    end
    
    protected
    
      def generate_tasks *args
        raise "This method is abstract and should have been redefined."
      end
      
      def start_tasks *tasks
        tasks.each{ |task| @parent.queue task }
      end
    
      def custom_defaults
        self.interval = 10
        self.name = SecureRandom.hex(10)
        self.repeat = true
      end
      
      def build_proc
        proc{ |*args|
          loop do
            start = Time.now
            generate_tasks
            sleep(BBLib::keep_between(@interval - (Time.now - start), 0, nil))
          end
        }
      end

  end

end


require_relative 'dynamic_tasks/dynamic_scripts'
