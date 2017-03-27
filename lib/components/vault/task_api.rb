module TaskVault
  class Task < SubComponent

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
