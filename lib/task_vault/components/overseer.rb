module TaskVault
  class Overseer
    include Runnable
    include BBLib::Prototype

    attr_float_between 0, nil, :capacity, default: 100, allow_nil: true
    attr_int_between 0, nil, :retention, default: 10, allow_nil: true
    attr_ary_of Task, :tasks

    alias components tasks

    def add(task, &block)
      task = Task.new(task, &block) if task.is_a?(Hash)
      return find(task) if tasks.include?(task)
      task.tap do |task|
        task.status = :queued
        task.parent = self
        tasks << task
      end
    end

    def remove(task)
      return nil unless task = find(task)
      tasks.delete(task)
    end

    def find(id)
      case id
      when Task
        tasks.include?(task) ? task : nil
      else
        tasks.find { |task| task.id == id }
      end
    end

    def used_capacity
      running.inject(0) { |sum, task| sum += task.weight }
    end

    [:queued, :running, :finished].each do |type|
      define_method(type) do
        tasks.find_all { |task| Task::STATUSES[task.status][:queue] == type }
      end
    end

    def sort!
      tasks.sort_by do |task|
        [Task::STATUSES[task.status][:sort], task.priority]
      end
    end

    def elevate!
      [queued, running].flatten.each do |task|
        task.elevate if task.elevate?
      end
    end

    def clean_finished
      sort!
      while retention && finished.size > retention
        tasks.delete(finished.last)
      end
    end

    def active?
      !queued.empty? || !running.empty? || finished.any?(&:repeat?)
    end

    protected

    def simple_setup
      self.interval = 0.1
    end

    def run(*args, &block)
      elevate!
      sort!
      process_queued
      process_running
      process_finished
      clean_finished
    end

    def process_queued
      return if used_capacity >= capacity || queued.empty?
      queued.map do |task|
        next unless task.ready? && (task.priority.zero? || used_capacity + task.weight <= capacity)
        task.start
      end.compact.size
    end

    def process_running
      running.each do |task|
        task.timeout! if task.timeout?
      end
    end

    def process_finished
      finished.each do |task|
        task.status = :queued if task.finished? && task.repeat?
      end
    end
  end
end
