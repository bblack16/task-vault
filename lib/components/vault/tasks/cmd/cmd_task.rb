# frozen_string_literal: true
require 'open3'

module TaskVault
  module Tasks
    class CMDTask < Task
      attr_string :command, default: '', serialize: true, always: true
      attr_dir :working_directory, allow_nil: true, serialize: true, always: true, pre_proc: proc { |x| x.to_s.empty? ? nil : x }
      attr_array :arguments, default: [], serialize: true, always: true

      # views_path File.expand_path('../app/views', __FILE__)

      alias cmd= command=
      alias cmd command

      alias args= arguments=
      alias args arguments

      component_aliases(:cmd, :cmd_task)

      def compile_cmdline
        cmd = arguments.map do |a|
          if a.include?(' ') && !a.encap_by?('"')
            "\"#{a.gsub('"', '\\"')}\""
          else
            a
          end
        end
        cmd.unshift(command)
        cmd.join(' ')
      end

      # get '/' do
      #   view_render :slim, :index
      # end

      protected

      def run
        command = compile_cmdline
        queue_info("About to run cmd: #{command}")
        Open3.popen3(command, chdir: (working_directory || '/')) do |_i, o, e, w|
          @pid = w.pid
          [o, e].each do |stream|
            stream.each do |line|
              queue_msg(line, severity: (stream == o ? :info : :error), event: (stream == o ? :stdout : :stderr))
            end
          end
        end
      end

      def msg_metadata
        {
          pid: @pid || nil
        }.merge(super)
      end
    end
  end
end
