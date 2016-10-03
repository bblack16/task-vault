require 'open3'

module TaskVault

  class CMDTask < Task

    attr_string :command, default: ''
    attr_valid_dir :working_directory, allow_nil: true
    attr_array :arguments, default: []

    alias_method :cmd=, :command=
    alias_method :cmd, :command

    alias_method :args=, :arguments=
    alias_method :args, :arguments

    protected

      def run
        command = compile_cmdline
        queue_msg("About to run cmd: #{command}", severity: :debug)
        Open3.popen3(command, chdir: (@working_directory || '/')) do |i, o, e, w|
          @pid = w.pid
          [o, e].each do |stream|
            stream.each do |line|
              queue_msg(line, severity: (stream == o ? :info : :error))
            end
          end
        end
      end

      def compile_cmdline
        cmd = @arguments.map do |a|
          if a.include?(' ') && !a.encap_with?('"')
            "\"#{a.gsub('"', '\\"')}\""
          else
            a
          end
        end
        cmd.unshift(@command)
        cmd.join(' ')
      end

      def msg_metadata
        {
          pid: (@pid rescue nil)
        }.merge(super)
      end

      def setup_serialize
        serialize_method :command, always: true
        serialize_method :arguments, always: true
        serialize_method :working_directory, always: true
        super
      end

  end

end
