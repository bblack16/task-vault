module TaskVault

  class ScriptDir < Task

    attr_valid_dir :path, allow_nil: nil
    attr_bool :recursive, default: true
    attr_int_between 0.001, nil, :interval, default: 10
    attr_hash :interpreters, :script_settings
    attr_reader :scripts

    def calculate_start_time
      self.start_at = Time.now
      true
    end

    def add_interpreter name:, filters:, path: nil
      @interpreters[name.to_sym] = { filters: filters, path: path }
    end

    def remove_interpreter name
      @interpreters.delete name
    end

    def set_script_setting args
      args.each do |key, value|
        @script_settings[key] = value
      end
    end

    alias_method :set, :set_script_setting
    alias_method :settings=, :set_script_setting

    protected

      def setup_defaults
        @scripts      = Hash.new
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
                task = CMDTask.new( build_task( script, (info[:path] || name) ) )
                @scripts[script] = task
                @parent.add(task)
                queue_msg("Found new script: '#{script}'. It has been added to Vault using interpreter #{name}.", severity: :debug)
              end
              script
            end
          end.flatten

          @scripts.find_all{ |path, task| !paths.include?(path) }.to_h.each do |n, t|
            t.cancel
            @scripts.delete(n)
            queue_msg("Script no longer found in path. Canceling and removing '#{n}'.", severity: :info)
          end
        end
      end

      def build_task script, path
        @script_settings.merge({
          name:      script.file_name(false),
          command:   path,
          arguments: [script]
        })
      end

      def setup_serialize
        serialize_method :path, always: true
        serialize_method :interval, always: true
        serialize_method :recursive, always: true
        serialize_method :interpreters, always: true
        serialize_method :script_settings, always: true
        super
      end

  end

end
