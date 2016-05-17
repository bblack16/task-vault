
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
      task = Task.load(task) if task.is_a?(Hash) || task.is_a?(String)
      [task].flatten.each do |t|
        @tasks[t.name] = t if t.is_a?(Task)
      end
    end

    def save_script name, script
      script.to_file(@path + 'scripts/' + name.to_s, mode: 'w')
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
          add_task Task.load(file, "#{@path}/templates")
        rescue StandardError, Exception => e
          queue_msg("Workbench failed to construct task from file '#{file}'. It will not be added to the vault. Please fix or remove it. #{e}", severity: 3)
          queue_msg(e, severity: 3)
        end
      end
      true
    end

    protected

      def init_thread
        @thread = Thread.new {
          queue_msg 'Workbench\'s scheduler is firing up...', severity: 6
          begin
            loop do
              start = Time.now.to_f

              queue_msg 'Workbench is checking for new/updated/removed tasks.', severity: 8

              begin
                load_cfg
              rescue StandardError => e
                queue_msg "Workbench failed to load config: #{e}", severity: 3
              end

              counts = { new:0, updated:0, removed:0 }
              task_set = []

              # Load tasks. Checks for changes and updates any tasks that have been modified in the cfg.
              @tasks.each do |name, t|
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

              # Delete any tasks that are still running but have been removed from cfg.
              @active.each do |n, s|
                if !task_set.include?(n)
                  @parent.vault.cancel(n)
                  @active.delete(n)
                  counts[:removed]+=1
                end
              end

              queue_msg("Workbench completed check. Currently managing #{task_set.count} tasks. #{counts.map{ |k, v| "#{v} #{k}"}.join(', ')}", severity:(counts.any?{|k,v| v > 0} ? 5 : 7))

              sleep_time = @interval - (Time.now.to_f - start)
              sleep(sleep_time < 0 ? 0 : sleep_time)
            end
          rescue StandardError, Exception => e
            queue_msg(e, severity: 2)
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
