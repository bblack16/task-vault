class TaskVault

  class TaskQueue
    attr_reader :tasks, :retention
    include BBLib

    def initialize retention: nil
      @tasks = {
        queued: [],
        ready: [],
        running: [],
        done: []
      }
      self.retention = retention
    end

    def retention= r
      @retention = r.nil? ? nil : BBLib::keep_between(r, 0, nil)
    end

    def queue task
      raise ArgumentError, "Invalid type passed to TaskQueue. Got a '#{task.class}', expected a TaskVault::Task." unless task.is_a?(Task)
      task.status = :queued
      @tasks[:queued].push task
    end

    def cancel task
      retrieve(task).each do |t|
        t.cancel
        move_task(t, :canceled)
      end
    end

    def sort
      @tasks[:queued].sort_by!{ |t| [t.priority, t.queued] }
      @tasks[:ready].sort_by!{ |t| [t.priority, t.added] }
      nil
    end

    # Cancels all jobs and clears all completed tasks
    def flush
      tasks.each{ |t| cancel(t) }
      clear
    end

    # Removes all completed tasks
    def clear
      @tasks[:done].clear
    end

    # Removes enough completed tasks to make it down to the retention limit.
    def clean
      if @retention then @tasks[:done].shift until @tasks[:done].size <= @retention end
      nil
    end

    def move_task task, status
      raise "Invalid status. Cannot move task to '#{status}'." unless STATUSES.include?(status)
      move_to = @tasks[STATUSES[status]]
      tasks = retrieve(task)
      @tasks.map{|k,v| v}.each do |q|
        tasks.each do |t|
          if q.include?(t)
            move_to.push(q.delete(t))
            t.status = status
          end
        end
      end
    end

    def tasks
      @tasks.map{|k,v| v}.flatten
    end

    def task_list *attributes
      attributes = [:name, :status] if attributes.empty?
      tasks.map do |t|
        attr = Hash.new
        attributes.each{ |a| attr[a] = t.send(a) }
        [t.id, attr]
      end.to_h
    end

    def active_tasks
      [@tasks[:queued], @tasks[:ready], @tasks[:running]].flatten
    end

    # Tasks can be retrieved by id, name or with by passing the actual task object.
    # An array containing the above can also be passed.
    def retrieve task
      tasks.find_all{ |t| (task.is_a?(Array) && (task.include?(t.id) || task.include?(t.name) || task.include?(t))) || t.id == task || t.name == task || t == task }
    end

    def status_of id, name: false
      retrieve(id).map{ |t| [(name ? t.name : t.id), t.status] }.to_h
    end

    def value_of id, name: false
      retrieve(id).map{ |t| [(name ? t.name : t.id), t.value] }.to_h
    end

    def ready_up
      total = 0
      @tasks[:queued].each do |t|
        if t.start_at <= Time.now && dependency_check(t)
          move_task(t, :ready)
          total+=1
        end
      end
      total == 0 ? nil : "INFO - Moved #{total} tasks from queued to ready."
    end

    def elevate_tasks policy
      @tasks[:ready].each do |t|
        next unless policy.include?(t.priority)
        delay = policy[t.priority]
        t.elevate if Time.now - t.last_elevated >= delay
      end
      nil
    end

    def check_running
      msgs = []
      @tasks[:running].each do |t|
        if t.thread.alive? && !t.max_life.nil? && Time.now - r.started > r.max_life
          move_task(t, :timeout)
          msgs.push "WARN - Task '#{t.name} (ID: #{t.id})' has exceeded its max life and had to be put down."
        end
        if !t.thread.alive?
          if parse_repeat(t)
            move_task(t, :queued)
            msgs.push "INFO - Task '#{t.name} (ID: #{t.id})' has finished and will repeat. Next eligible time is #{t.start_at}"
          else
            move_task(t, (t.thread.value.is_a?(Exception) ? :error : :finished) )
            msgs.push "INFO - Task '#{t.name} (ID: #{t.id})' completed with no repeat toggled. Result was (first 50 chars): #{t.value.to_s[0..50]}"
          end
        end
      end
      return msgs
    end

    def running_weight
      @tasks[:running].inject{ |sum, x| sum + x.weight }.to_f
    end

    def run_tasks limit
      msgs, weight = [], running_weight
      @tasks[:ready].each do |t|
        if limit.nil? || t.weight + weight <= limit || t.priority == 0
          if t.run
            move_task(t, :running)
            msgs.push "INFO - Task '#{t.name} (ID: #{t.id})' has started!"
            weight+= t.weight
          else
            move_to(t, :error)
            msgs.push "ERROR - An error occured while trying to build task '#{t.name} (ID: #{t.id})'. It could not be run."
          end
        end
      end
      return msgs
    end

    def dependency_check task
      ready = true
      task.dependencies.each do |n, t|
        deps = retrieve(n)
        if deps.empty?
          move_task(task, :missing_dependency)
          ready = false
        else
          case t.to_sym
          when :wait
            if deps.any?{ |d| [:queued, :waiting, :ready, :running].include?(d.status) }
              move_task(task, :waiting)
              ready = false
            end
          when :prereq, :value
            if deps.any?{ |d| [:timeout, :error, :canceled, :failed_dependency].include?(d.status) }
              ready = false
              move_task(task, :failed_dependency)
            elsif t == :value && !deps.any?{ |d| [:queued, :waiting, :ready, :running].include?(d.status) }
              task.dargs = deps.map{ |d| d.value }
            else
              move_task(task, :waiting)
              ready = false
            end
          end
        end
      end
      ready
    end

    def parse_repeat task
      repeat = (task.repeat == true || task.repeat.is_a?(Numeric) && task.repeat.to_i > task.run_count || task.repeat.is_a?(Time) && Time.now < task.repeat || task.repeat.is_a?(String) )
      if repeat && task.repeat.is_a?(String)
        if task.repeat.start_with?('after:')
          task.start_at = Time.now + task.repeat.parse_duration(output: :sec)
        elsif task.repeat.start_with?('every:')
          task.start_at = Time.at(task.started + task.repeat.parse_duration(output: :sec))
        elsif Cron.valid?(task.repeat) # For cron syntax
          task.start_at = Cron.next(task.repeat)
        elsif task.repeat == 'from_value'
          val = task.value.to_a.last
          if val.is_a?(Exception) || val == 'stop' || val == 'false'
            repeat = false
          else
            begin
              if val.strip =~ /\A\d+\z/ || val.strip =~ /\A\d+\.\d+\z/
                task.start_at = Time.now + val.to_s.to_f
              elsif Cron.valid?(val)
                task.start_at = Cron.next(val)
              else
                task.start_at = Time.parse(val)
              end
            rescue
              repeat = false
            end
          end
        else
          repeat = false
        end
      end
      if repeat
        move_task(task, :queued)
        task.priority = task.initial_priority
      end
      repeat
    end

    STATUSES = {
      queued: :queued,
      ready: :ready,
      running: :running,
      finished: :done,
      error: :done,
      waiting: :queued,
      failed_dependency: :done,
      missing_dependency: :queued,
      timeout: :done,
      canceled: :done,
      unknown: :done
    }

  end

end
