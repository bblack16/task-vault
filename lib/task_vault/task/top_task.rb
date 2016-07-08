
class TaskVault

  class TopTask < Task
    attr_reader :cpu, :memory, :processes, :uptime, :os
    attr_accessor :get_processes, :get_os

    def ignore_on_serialize
      super + [ :cpu, :memory, :processes, :uptime, :os ]
    end

    protected

      def hide_on_inspect
        super + [:@processes]
      end

      def custom_defaults
        self.repeat = '* * * * * *'
        @cpu = Hash.new
        @memory = Hash.new
        @processes = Array.new
        @uptime = nil
        @get_processes = true
        @get_os = true
      end

      def build_proc *args, **named
        proc{ |*args|
          stats = BBLib::OS.system_stats
          @cpu = stats[:cpu]
          @memory = stats[:memory]
          @uptime = stats[:uptime]
          @processes = BBLib::OS.processes if @get_processes
          @os = BBLib::OS.os_info if @get_os
          stats.to_json
        }
      end

  end

end
