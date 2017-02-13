
module TaskVault
  class Component < BBLib::LazyClass
    VERBS = [:get, :put, :post, :delete]

    after :setup_routes, :lazy_init

    def routes
      @routes ||= {}
    end

    def params
      @params ||= {}
    end

    def params=(params)
      @params = params
    end

    def add_route(verb, path, &block)
      raise ArgumentError, "Unknown http verb '#{verb}'. Verb must be of #{VERBS.join(', ')}" unless VERBS.include?(verb)
      (routes[verb] ||= {})[path] = block
    end

    def call_route(verb, path, *args)
      routes[verb][path].call(*args)
    end

    def get(path, &block)
      add_route(:get, path, &block)
    end

    def post(path, &block)
      add_route(:post, path, &block)
    end

    def put(path, &block)
      add_route(:put, path, &block)
    end

    def delete(path, &block)
      add_route(:delete, path, &block)
    end

    protected

    def setup_routes
      get '/' do
        self.serialize.merge(
          uptime: uptime,
          started: started,
          stopped: stopped,
          history: history[0..4].map { |h| "#{h[:time]} - #{h[:severity].to_s.upcase} - #{h[:msg]}" }
        )
      end
    end

  end
end
