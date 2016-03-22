
class TaskVault

  class Workbench < Component
    attr_reader :path, :tasks, :dynamic_tasks, :active, :interval

    # 0 is HIGHLY not recommended as it is massive overkill for message processing in most cases
    def interval= i
      @interval = BBLib.keep_between(i, 0, nil)
    end

    def path= p
      @path = p.to_s + 'workbench.cfg'
    end

    def add_task task, name:nil, interpreter:nil, working_dir:nil, start_at:nil, type: :script, args:nil, weight:1, priority:3, max_life:nil, value_cap:10000, repeat:1, delay:nil, message_handler_name: :default
      if !task.is_a?(Task) && !task.is_a?(Array) && !task.is_a?(DynamicTask)
        task = Task.new(name:name, interpreter:interpreter, working_dir:working_dir, type:type, job:task, args:args, weight:weight, priority:priority, max_life:max_life, value_cap:value_cap, repeat:repeat, delay:delay, message_handler_name:message_handler_name)
      end
      [task].flatten.each do |t|
        if t.is_a?(Task)
          @tasks[t.name] = t
        elsif t.is_a?(DynamicTask)
          @dynamic_tasks[t.name] = t
        end
      end
    end

    def remove_task name
      @tasks.delete name
    end

    def save overwrite = true, format: :yaml
      hash = {'interval' => @interval, 'tasks' => {}, 'dynamic_tasks' => {}}
      @tasks.each do |n, t|
        hash['tasks'][n.to_s] = t.serialize
      end
      @dynamic_tasks.each{ |n, d| hash['dynamic_tasks'][n] = d.serialize }
      if format == :yaml
        hash.to_yaml.to_file(@path, mode:'w')
      else
        hash.to_json.to_file(@path, mode:'w')
      end
      true
    end

    def load_cfg
      raise "Invalid path for Docket: #{@path}" unless File.exists?(@path) || (File.write(@path, '') && save)
      raw = File.read(@path).to_s
      if raw.strip.start_with?('{')
        cfg = JSON.parse(raw)
      else
        cfg = YAML.load(raw)
      end
      return cfg unless Hash === cfg
      cfg.keys_to_sym!
      cfg[:tasks].each do |k, v|
        begin
          add_task Task.new(v)
        rescue
        end
      end
      cfg[:dynamic_tasks].each do |k, v|
        begin
          add_task( Object.const_get(v.delete(:class)).new(v) )
        rescue
        end
      end
      self.interval = cfg[:interval]
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
              @tasks.each do |n, t|
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

              # Load dynamic tasks to see if there are any new tasks to start or any that have changed.
              @dynamic_tasks.each do |name, d|
                d.generate_tasks.each do |t|
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
