# frozen_string_literal: true
require 'open3'

module TaskVault
  module Tasks
    class CMDTask < Task
      attr_string :command, default: '', serialize: true, always: true
      attr_valid_dir :working_directory, allow_nil: true, serialize: true, always: true, pre_proc: proc { |x| x.to_s.empty? ? nil : x }
      attr_array :arguments, default: [], serialize: true, always: true

      alias cmd= command=
      alias cmd command

      alias args= arguments=
      alias args arguments

      add_alias(:cmd, :cmd_task)

      protected

      def run
        command = compile_cmdline
        queue_msg("About to run cmd: #{command}", severity: :debug)
        Open3.popen3(command, chdir: (@working_directory || '/')) do |_i, o, e, w|
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
          if a.include?(' ') && !a.encap_by?('"')
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
          pid: @pid || nil
        }.merge(super)
      end
    end
  end
end
