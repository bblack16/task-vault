# frozen_string_literal: true
module TaskVault
  module Tasks
    class ScriptDir < Task
      attr_valid_dir :path, allow_nil: nil, serialize: true, always: true
      attr_bool :recursive, default: true, serialize: true, always: true
      attr_int_between 0.001, nil, :interval, default: 10, serialize: true, always: true
      attr_hash :interpreters, :script_settings, serialize: true, always: true
      attr_reader :scripts

      component_aliases(:script_dir, :scriptdir, :script_directory)

      def calculate_start_time
        self.start_at = Time.now
        true
      end

      def add_interpreter(name:, filters:, path: nil)
        @interpreters[name.to_sym] = { filters: filters, path: path }
      end

      def remove_interpreter(name)
        @interpreters.delete name
      end

      def set_script_setting(args)
        args.each do |key, value|
          @script_settings[key] = value
        end
      end

      alias set set_script_setting
      alias settings= set_script_setting

      protected

      def setup_defaults
        @scripts      = {}
        @interpreters = {
          ruby: { filters: ['*.rb'], path: Gem.ruby }
        }
        @script_settings = Task.new.serialize
        @script_settings.delete :class
        @script_settings.delete :name
      end

      def run
        loop do
          paths = @interpreters.map do |name, info|
            BBLib.scan_files(@path, filter: info[:filters], recursive: @recursive).map do |script|
              unless @scripts.include?(script)
                task = CMDTask.new(build_task(script, (info[:path] || name)))
                @scripts[script] = task
                @parent.add(task)
                queue_info("Found new script: '#{script}'. It has been added to Vault using interpreter #{name}.")
              end
              script
            end
          end.flatten

          @scripts.find_all { |path, _task| !paths.include?(path) }.to_h.each do |n, t|
            t.cancel
            @scripts.delete(n)
            queue_info("Script no longer found in path. Canceling and removing '#{n}'.")
          end
        end
      end

      def build_task(script, path)
        @script_settings.merge(
          name:      script.file_name(false),
          command:   path,
          arguments: [script]
        )
      end
    end
  end
end
