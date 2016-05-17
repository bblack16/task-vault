require 'securerandom'
require 'open3'

class TaskVault

  class CMDTask < Task
    attr_reader :type, :cmd, :dependency_args, :interpreter

    TYPES = [
      :cmd, :script, :eval  #, :eval_proc
    ]
    
    def type= t
      @type = TYPES.include?(t.to_sym) ? t.to_sym : nil
    end

    def cmd= pr
      @cmd = pr
    end

    def interpreter= i
      @interpreter = i
    end

    def args
      @args + @dependency_args
    end

    def dependency_args= a
      @dependency_args = a.nil? ? [] : [a].flatten(1)
    end

    def ignore_on_serialize
      super + [ 'dependency_args' ]
    end

    protected

      def custom_defaults
        @dependency_args = []
        self.type = :cmd
        self.cmd = nil
        self.interpreter = nil
      end

      def build_proc *args, **named
        case @type
        when :proc
          @cmd.is_a?(Proc) ? @cmd : nil
        when :cmd
          cmd_proc(generate_cmd(@cmd, args))
        when :script
          interpreter = @parent.get_interpreter(@interpreter, @cmd) rescue nil
          cmd_proc("#{interpreter} #{generate_cmd(@cmd, args)}")
        when :eval
          cmd_proc("#{Gem.ruby} -e \"#{@cmd.gsub("\"", "\\\"")}\" #{setup_args(args)}")
        else
          nil
        end
      end

      def cmd_proc cmd
        proc{ |*args|
          results = Open3.popen3(cmd, chdir: (@working_dir || "/")) do |i, o, e, w|
            queue_msg("Task '#{@name}' has started and has a pid of #{w.pid}", severity: 6)
            o.map do |line|
              msg = process_line(line)
              if !msg.nil?
                queue_msg(msg, task_name: @name, task_id: @id, severity: 5)
              end
              msg
            end.reject{ |m| m.nil? }
          end
          results.shift until results.size <= @value_cap if @value_cap
          results
        }
      end
      
      # This exists for sub classes. It allows output to be modded
      # Return nil to ignore this line (not log it and not save it to history)
      def process_line line
        line
      end
      
      def generate_cmd cmd, args
        "#{cmd} #{setup_args(args)}"
      end

  end

end
