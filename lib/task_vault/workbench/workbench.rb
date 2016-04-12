
class TaskVault

  class Workbench < Component
    attr_reader :path, :tasks, :active, :interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def path= p
      @path = p.to_s
    end

    def add_task task
      task = BaseTask.load(task) if task.is_a?(Hash) || task.is_a?(String)
      [task].flatten.each do |t|
        if t.is_a?(BaseTask)
          @tasks[t.name] = t
        end
      end
    end

    def remove_task name
      @tasks.delete name
    end

    def delete_task name
      remove_task name
      path = @path + "recipes/#{name}"
      path+= (File.exists?(path + '.yml') ? '.yml' : (File.exists?(path + '.json') ? 'json' : nil))
      File.delete(path)
    end

    def save default_format = :yaml
      @tasks.each do |n, t|
        path = @path + "recipes/#{t.name}"
        format = (File.exists?(path + '.yml') ? :yaml : (File.exists?(path + '.json') ? :json : default_format))
        if format == :yaml
          t.serialize.to_yaml.to_file(path + ".yml", mode:'w')
        else
          t.serialize.to_file(path + ".json", mode:'w')
        end
      end
      true
    end

    def load_cfg
      BBLib.scan_files(@path + 'recipes/', filter: ['*.yaml', '*.yml', '*.json'], recursive: true).each do |file|
        begin
          add_task Task.load(file)
        rescue StandardError, Exception => e
          queue_msg("WARN - Workbench failed to construct task from file '#{file}'. It will not be added to the vault. Please fix or remove it. #{e}")
        end
      end
      true
    end

    protected

      def init_thread
        @thread = Thread.new {
          queue_msg 'INFO - Workbench\'s scheduler is firing up...'
          begin
            loop do
              start = Time.now.to_f

              queue_msg 'DEBUG - Workbench is checking for new/updated/removed tasks.'

              begin
                load_cfg
              rescue StandardError => e
                queue_msg "ERROR - Workbench failed to load config: #{e}"
              end

              counts = { new:0, updated:0, removed:0 }
              task_set = []

              # Load tasks. Checks for changes and updates any tasks that have been modified in the cfg.
              @tasks.each do |name, task|
                (task.is_a?(DynamicTask) ? task.generate_tasks : [task]).flatten.each do |t|
                  n = t.name
                  task_set.push(n)
                  if @active.include?(n) && @active[n] != t.serialize
                    @parent.vault.cancel(n)
                    @parent.vault.queue t
                    @active[n] = t.serialize
                    counts[:updated]+=1
                  elsif @active[n].nil?
                    @parent.vault.queue t
                    @active[n] = t.serialize
                    counts[:new]+=1
                  end
                end
              end

              # Delete any tasks that are still running but have been removed from cfg.
              @active.each do |n, s|
                if !task_set.include?(n)
                  @parent.vault.cancel(n)
                  @active.delete(n)
                  counts[:removed]+=1
                end
              end

              queue_msg("#{counts.any?{|k,v| v > 0} ? "INFO" : "DEBUG"} - Workbench completed check. #{counts.map{ |k, v| "#{v} #{k}"}.join(', ')}")

              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            queue_msg(e)
            e
          end
        }
        @started = Time.now
      end

      def setup_defaults
        @active, @dynamic_tasks, @tasks = {}, {}, {}
        self.interval = 60
        self.path = Dir.pwd
      end


  end

end
