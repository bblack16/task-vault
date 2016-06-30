require_relative 'task_queue'

class TaskVault

  class Vault < Component
    attr_reader :queue, :limit, :elevation_policy, :interval, :path

    def limit= l
      @limit = l.nil? ? nil : BBLib::keep_between(l, 0, nil)
    end

    def path= p
      @path = p.to_s.pathify
      @queue.path = @path
    end

    def interval= i
      @interval = i.nil? ? nil : BBLib.keep_between(i, 0, nil)
    end

    def queue task
      @queue.queue task
    end

    def method_missing *args, **named
      if @queue.respond_to?(args.first)
        if named.empty?
          @queue.send(args.first, *args[1..-1])
        else
          @queue.send(args.first, *args[1..-1], **named)
        end
      else
        raise NoMethodError, "Missing method for '#{args.first}' in #{self.class}"
      end
    end

    def methods
      (@queue.methods + super).uniq
    end

    def save_task *task, format: :yaml
      @queue.retrieve(*task).map{ |t| [t.name, t.save(@path + '/recipes', format)] }.to_h
    end

    protected

      def setup_defaults
        @queue = TaskQueue.new
        @elevation_policy = { 0 => nil, 1 => 60, 2 => 30, 3 => 30, 4 => 60, 5 => 120, 6 => nil }
        @interval, @limit = 0.2, 5
      end

      def init_thread
        @thread = Thread.new {
          begin
            loop do
              start = Time.now.to_f

              [:sort, :ready_up, [:elevate_tasks, @elevation_policy], :sort, :check_running, [:run_tasks, @limit], :clean].each do |method|
                @queue.send(*method)
              end

              @queue.read_msgs.each{ |msg| queue_msg(msg[:msg], **msg[:meta]) }

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
