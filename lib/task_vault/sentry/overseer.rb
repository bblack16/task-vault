class TaskVault

  class Overseer < Component
    attr_reader :response

    def handle_request msg
      @response = { time: Time.now, source: msg, requests:[], error:nil }
      begin
        request = (JSON.parse(msg) rescue YAML.load(msg)).keys_to_sym
        parse request
      rescue StandardError => e
        queue_msg "Overseer could not parse request #{msg}. It must be valid JSON or YAML."
        @response[:error] = "Overseer could not parse request #{msg}. It must be valid JSON or YAML: Error MSG = #{e} #{e.backtrace}"
      end
      @response
    end

    protected

      OBJECTS = [:vault, :workbench, :protectron, :courier, :sentry]

      def parse request
        request.map do |obj, calls|
          return calls.map do |r, args|
            req = {object:obj, command: r, arguments: args, status: :success}
            begin
              req[:response] = execute(obj, r, args)
            rescue StandardError, Exception => e
              req[:status] = :error
              req[:response] = "Error processing cmd '#{r}' with arguments '#{args}'. Error: #{e} - #{e.backtrace.join("\n")}"
            end
            @response[:requests].push req
          end
        end
      end

      def execute obj, cmd, named
        args = named.is_a?(Hash) ? named.delete(:args) : named
        named = {} if named.nil? || !named.is_a?(Hash)
        if OBJECTS.include?(obj)
          obj = @parent.send(obj)
        elsif obj == :task_vault
          obj = @parent
        elsif @parent.courier.handler_list.include?(obj)
          obj = @parent.courier.handlers.find{|f| f.name == obj}
        else
          raise ArgumentError, "No object matching '#{obj}' exists"
        end

        a = !args.nil? && (!args.is_a?(Array) || !args.empty?)
        n = !named.nil? && !named.empty?

        if a && n
          obj.send(cmd, *args, **named)
        elsif !a && n
          obj.send(cmd, **named)
        elsif a && !n
          obj.send(cmd, *args)
        else
          obj.send(cmd)
        end
      end

  end

end
