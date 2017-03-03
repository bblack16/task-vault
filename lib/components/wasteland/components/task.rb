module TaskVault
  class Task < SubComponent

    def call_route(verb, route, params)
      @params = params
      block = find_route(verb, route)
      if block
        block.call
      else
        { status: :error, message: "No route found matching '#{verb} #{route}'."}
      end
    end

    def params
      @params ||= {}
    end

    def describe
      super.merge(
        status:           status,
        stats:            stats,
        run_count:        run_count,
        initial_priority: initial_priority,
        running:          running?,
        times:            times
      )
    end

    protected

    def routes_for(verb)
      (@routes ||= {})[verb] ||= {}
    end

    def add_route(verb, path, &block)
      raise ArgumentError, "Unknown http verb '#{verb}'. Verb must be of #{VERBS.join(', ')}" unless VERBS.include?(verb)
      routes_for(verb)[path] = block
    end

    def find_route(verb, route)
      routes_for(verb).find { |r, b| r.is_a?(String) ? r.downcase == route.downcase : r =~ route }.last
    end

    def setup_routes

      [:stats, :times].each do |method|
        get "/#{method}" do
          send(method)
        end
      end

      get '/routes' do
        @routes.map do |verb, routes|
          [
            verb,
            routes.map { |r, _b| "/components/#{parent.name}/tasks/#{id}#{r}" }
          ]
        end.to_h
      end

    end
  end
end
