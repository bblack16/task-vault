require_relative 'task_queue'

class TaskVault

  class Vault < Component
    attr_reader :queue, :limit, :last_id, :elevation_policy, :interval

    def limit= l
      @limit = l.nil? ? nil : BBLib::keep_between(l, 0, nil)
    end

    def interval= i
      @interval = i.nil? ? nil : BBLib.keep_between(i, 0, nil)
    end

    def method_missing *args, **named
      if @queue.respond_to?(args.first)
        if named.empty?
          @queue.send(args.first, *args[1..-1])
        else
          @queue.send(args.first, *args[1..-1], **named)
        end
      else
        raise ArgumentError, "Missing method for '#{args.first}' in #{self.class}"
      end
    end

    protected

      def setup_defaults
        @queue = TaskQueue.new
        @elevation_policy = { 0 => nil, 1 => 60, 2 => 30, 3 => 30, 4 => 60, 5 => 120, 6 => nil }
        @last_id, @interval, @limit = 0, 0.2, 5
      end

      def init_thread
        # [:sort, :ready_up, [:elevate_tasks, @elevation_policy], :sort, :check_running, [:run_tasks, @limit], :clear].each do |method|
        #   @queue.send(*method).to_a.each{ |m| queue_msg(m)}
        # end
        @thread = Thread.new {
          begin
            loop do
              start = Time.now.to_f

              [:sort, :ready_up, [:elevate_tasks, @elevation_policy], :sort, :check_running, [:run_tasks, @limit], :clean].each do |method|
                @queue.send(*method).to_a.each{ |m| queue_msg(m)}
              end

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
