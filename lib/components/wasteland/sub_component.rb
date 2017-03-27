
module TaskVault
  class SubComponent < Component

    def call_route(verb, route, params, request)
      @params = params
      @request = request
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

    def request
      @request
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
      routes_for(verb).find { |r, b| r.is_a?(String) ? r.downcase == route.downcase : r =~ route }&.last
    end

    def _setup_routes
      super

      get '/routes' do
        @routes.map { |k, v| [k, v.keys.map { |r| request.path_info.sub('/routes', r) } ] }.to_h
      end
    end

  end
end
