require_relative 'tasks/_tasks'
# frozen_string_literal: true
module TaskVault
  class Vault < ServerComponent
    attr_float_between 0, nil, :limit, default: 5, allow_nil: true, serialize: true, always: true
    attr_float_between 0, nil, :interval, default: 0.1, serialize: true, always: true
    attr_int_between 0, nil, :retention, default: 100, allow_nil: true, serialize: true, always: true
    attr_int_between 1, nil, :elevate_interval, default: 300, allow_nil: true, serialize: true, always: true
    attr_ary_of String, :blacklist, add_rem: true, default: [], serialize: true, always: true
    attr_dir :path, serialize: true, always: true
    attr_reader :tasks, serialize: false

    STATUSES = {
      queued:             :queued,
      ready:              :ready,
      running:            :running,
      finished:           :done,
      error:              :done,
      waiting:            :queued,
      failed_dependency:  :queued,
      missing_dependency: :queued,
      timeout:            :done,
      canceled:           :done,
      unknown:            :done
    }.freeze

    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      super
    end

    def self.description
      'If you\'ve got something that needs doin\', look no further than Vault! Vault is a task running enginge for ' \
      'TaskVault. It manages tasks (objects inherited from TaskVault::Task) and runs them within a queue. Vault uses ' \
      'escalation policies and a weighted queueing mechanism to ensure your tasks are run when they need to be without ' \
      'undue stress on your system. Pop in a task and get going today!'
    end

    def read_msg
      if message_queue.empty?
        all_tasks.find(&:has_msg?)&.read_msg
      else
        message_queue.shift
      end
    end

    def read_all_msgs
      all = []
      all.push(read_msg) while has_msg?
      all
    end

    def has_msg?
      !message_queue.empty? || all_tasks.any?(&:has_msg?)
    end

    def add(task)
      if existing = all_tasks.find { |t| t == task }
        return existing
      end
      raise ArgumentError, "Tasks of type #{task.is_a?(Hash) ? task[:class] : task.class} are blacklisted on this Vault instance." if blacklisted?(task)
      task        = Task.load(task, parent: self, namespace: Tasks)
      task.status = :queued
      task.id     = next_id
      task.parent = self
      tasks[:queued].push task
      task
    end

    alias add_task add

    def blacklisted?(obj)
      blacklist.any? do |b|
        obj.class.to_s == b || "TaskVault::#{obj.class}" == b ||
          obj.is_a?(Hash) && (
            obj[:class].to_s == b || "TaskVault::#{obj[:class]}" == b
          )
      end
    end

    def all_tasks
      tasks.map { |_q, t| t }.flatten
    end

    def find(id)
      all_tasks.find { |t| t.id == id }
    end

    alias task find

    def find_all(*ids)
      all_tasks.find_all { |t| ids.include?(t.id) }
    end

    def find_by(**query)
      all_tasks.find do |task|
        query.all? do |k, v|
          task.respond_to?(k) && task.send(k) == v rescue false
        end
      end
    end

    def where_is?(task_id)
      tasks.find { |_n, q| q.any? { |t| t.id == task_id } }.first
    rescue
      nil
    end

    def cancel(id)
      task(id).cancel
    rescue
      false
    end

    def remove(id)
      task = task(id)
      return false unless task
      task.cancel
      tasks.flat_map { |_q, t| t.delete(task) }.compact.first
    end

    def rerun(id)
      move_task(id, :queued)
    end

    # Cancels all tasks
    def cancel_all
      tasks.each { |_q, t| t.each(&:cancel) }
    end

    # Clears ALL completed tasks (successful or failed)
    def clear_completed
      tasks[:done].clear
    end

    # Removes enough completed tasks to meet the current retention policy
    def clean_completed
      tasks[:done].shift until tasks[:done].size <= retention if retention
    end

    def task_list(*attributes)
      attributes = [:name, :status, :class] if attributes.empty?
      all_tasks.map { |t| [t.id, t.details(*attributes)] }.to_h
    end

    def task_details(id, *attributes)
      task(id).details[*attributes]
    end

    def status_of(id)
      task(id).status
    end

    def handlers=(*handlers)
      super
      all_tasks.each do |task|
        task.handlers = *(handlers + task.handlers).flatten.uniq
      end
    end

    def self.registry
      TaskVault::Task.descendants
    end

    def running_weight
      tasks[:running].inject(0) { |sum, t| sum += t.weight }
    end

    protected

    def setup_defaults
      @tasks = {
        queued:  [],
        ready:   [],
        running: [],
        done:    []
      }
      @last_id = -1
      # require_relative 'api'
    end

    def next_id
      @last_id += 1
    end

    def run
      loop do
        start = Time.now
        canceled_check
        resort_tasks
        check_queued
        elevate_tasks
        resort_tasks
        check_running
        check_ready
        clean_completed
        sleep_time = interval - (Time.now.to_f - start.to_f)
        sleep(sleep_time <= 0 ? 0 : sleep_time)
      end
    end

    def canceled_check
      [:queued, :ready, :running].each do |type|
        tasks[type].each do |task|
          move_task task, :canceled if task.status == :canceled
        end
      end
    end

    def resort_tasks
      tasks[:queued].sort_by! { |t| [t.priority, t.queued] }
      tasks[:ready].sort_by! { |t| [t.priority, t.added] }
    end

    def move_task(task, status)
      status = :queued if status == :timeout && task.calculate_start_time
      move_to = tasks[STATUSES[status]]
      task = self.task(task) if task.is_a?(Integer)
      tasks.each do |_name, queue|
        if queue.include?(task)
          task.status = status
          task.status = :queued if status == :timeout && task.calculate_start_time
          move_to.push(queue.delete(task))
        end
      end
    end

    def check_queued
      total = 0
      tasks[:queued].each do |task|
        if task.start_at <= Time.now
          move_task(task, :ready)
          total += 1
        end
      end
      queue_msg("Moved #{total} task#{total > 1 ? 's' : nil} from queued to ready.", severity: :debug) if total.positive?
    end

    def elevate_tasks
      [tasks[:queued], tasks[:running]].each do |set|
        set.each do |task|
          task.elevate_check(elevate_interval)
        end
      end
    end

    def check_running
      tasks[:running].each do |task|
        if task.timeout?
          move_task(task, :timeout)
          queue_msg("Task #{task.id} (#{task.name}) has exceeded its max life and has been timed out.", severity: :warn)
        end
        next if task.running?
        failed = task.status != :finished
        if task.calculate_start_time
          move_task(task, :queued)
          queue_msg(
            "Task #{task.id} (#{task.name}) has finished and will repeat. Next eligible run time is #{task.start_at}.",
            severity: (failed ? :error : :info)
          )
        else
          move_task(task, (failed ? :error : :finished))
          queue_msg(
            "Task #{task.id} (#{task.name}) has finished and will not repeat. Final status: #{task.status}.",
            severity: (failed ? :error : :info)
          )
        end
      end
    end

    def check_ready
      weight = running_weight
      tasks[:ready].each do |task|
        next unless limit.nil? || task.priority.zero? || task.weight + weight <= limit
        move_task(task, :running)
        task.start
        weight += task.weight
      end
    end
  end
end
