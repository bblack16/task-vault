
class TaskVault

  class TopTask < Task
    attr_reader :cpu, :memory, :processes, :uptime, :os, :filesystems
    attr_accessor :get_processes, :get_os, :get_filesystem

    def ignore_on_serialize
      super + [ :cpu, :memory, :processes, :uptime, :os, :filesystems ]
    end

    protected

      def hide_on_inspect
        super + [:@processes, :@filesystems, :@cpu, :@processes, :@uptime, :@memory, :@os]
      end

      def custom_defaults
        self.repeat     = '* * * * * *'
        @cpu            = Hash.new
        @memory         = Hash.new
        @processes      = Array.new
        @uptime         = nil
        @get_processes  = true
        @get_os         = true
        @get_filesystem = true
      end

      def build_proc *args, **named
        proc{ |*args|
          stats        = BBLib::OS.system_stats
          @cpu         = stats[:cpu]
          @memory      = stats[:memory]
          @uptime      = stats[:uptime]
          @processes   = BBLib::OS.processes if @get_processes
          @os          = BBLib::OS.os_info if @get_os
          @filesystems = BBLib::OS.filesystems if @get_filesystem
          stats.to_json
        }
      end

  end

end
