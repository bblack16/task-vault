

class TaskVault

  class DynamicTask < Task
    attr_reader :interval, :parent_repeat
    
    def interval= it
      @interval = BBLib::keep_between(it, 0, nil)
    end
    
    def parent_repeat= pr
      @parent_repeat = pr
    end
    
    def repeat
      @parent_repeat
    end
    
    protected
    
      def generate_tasks *args
        raise "This method is abstract and should have been redefined."
      end
      
      def start_tasks tasks
        tasks.each{ |task| @parent.queue task if task.is_a?(Task) }
      end
    
      def custom_defaults
        self.interval = 10
        self.name = SecureRandom.hex(10)
        self.parent_repeat = true
      end
      
      def build_proc *args, **named
        proc{ |*args|
          loop do
            start = Time.now
            start_tasks(generate_tasks(*args))
            sleep(BBLib::keep_between(@interval - (Time.now - start), 0, nil))
          end
        }
      end

  end

end


require_relative 'dynamic_tasks/script_folder'
