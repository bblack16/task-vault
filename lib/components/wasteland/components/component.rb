
module TaskVault
  class Component < BBLib::LazyClass
    VERBS = [:get, :put, :post, :delete]

    after :setup_routes, :lazy_init

    protected

    def add_route(verb, path, &block)
      raise ArgumentError, "Unknown http verb '#{verb}'. Verb must be of #{VERBS.join(', ')}" unless VERBS.include?(verb)
      full_route = "/components/#{name}#{path}"
      Wasteland::Server.send(verb, full_route, &block) unless Wasteland::Server.route_names(verb).include?(full_route)
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

    def add_sub_component_routes(sub)
      return nil unless sub.respond_to?(:routes)
      sub.routes
    end

    def setup_routes
      get '/' do
        component.serialize.merge(
          description: component.description,
          uptime:      component.uptime,
          started:     component.started,
          stopped:     component.stopped,
          history:     component.history[0..9].map { |h| "#{h[:time]} - #{h[:severity].to_s.upcase} - #{h[:msg]}" }
        )
      end

      get '/settings' do
        component.serialize
      end

      post '/settings' do
        params.map do |k, v|
          if component.respond_to?("#{k}=")
            component.send("#{k}=", *[v].flatten(1))
            [k, component.send(k)]
          else
            [k, nil]
          end
        end.to_h
      end

      get '/logs' do
        process_component_logs(component.history)
      end

      get '/message_queue' do
        component.message_queue
      end

      [:start, :stop, :restart].each do |cmd|
        put "/#{cmd}" do
          { cmd => component.send(cmd) }
        end
      end
    end

  end
end
