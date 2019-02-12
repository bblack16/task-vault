module TaskVault
  class CMD < Task

    attr_str :command, required: true, arg_at: 0, aliases: [:cmd]
    attr_str :working_directory, default: nil, allow_nil: true
    attr_ary :arguments, default: []

    protected

    def run(*args, &block)
      require 'open3'
      debug("About to run command '#{command}'")
      Open3.popen3(compile_cmdline, chdir: (working_directory || '/')) do |_i, o, e, w|
        @pid = w.pid
        [o, e].each do |stream|
          stream.each do |line|
            queue_message(line, severity: (stream == o ? :info : :error), event: [(stream == o ? :stdout : :stderr)])
          end
        end
      end
    end

    def compile_cmdline
      compiled = [command] + arguments.flatten.map do |argument|
        if argument.include?(' ') && !argument.encap_by?('"')
          "\"#{argument.gsub('"', '\\"')}\""
        else
          argument.to_s
        end
      end
      compiled.join(' ')
    end
  end
end
