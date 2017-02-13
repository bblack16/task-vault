module TaskVault
  class Wasteland < ServerComponent
    class Server < Sinatra::Base

      def self.route_names(verb)
        return [] unless routes[verb.to_s.upcase]
        routes[verb.to_s.upcase].map { |r| r[0].to_s }
      end

      get '/' do
        content_type :json
        json_format(
          message: "Welcome to Wasteland VERSION #{Wasteland::VERSION}",
          wasteland: {
            version: Wasteland::VERSION,
            ip_address: settings.bind
          },
          health: parent.health,
          status: parent.status
        )
      end

      get '/routes' do
        content_type :json
        json_format(
          [:get, :post, :delete, :put].each_with_object({}) { |v, h| h[v] = Server.route_names(v) }
        )
      end

      get '/health' do
        content_type :json
        json_format(health: parent.health)
      end

      get '/status' do
        content_type :json
        json_format(parent.status)
      end

      get '/start' do
        content_type :json
        json_format(status: parent.start)
      end

      get '/stop' do
        content_type :json
        json_format(status: parent.stop)
      end

      get '/restart' do
        content_type :json
        json_format(status: parent.restart)
      end

      get '/components' do
        content_type :json
        json_format(parent.components.map { |k, v| [k, v.class.to_s] }.to_h)
      end

      get '/components/logs' do
        content_type :json
        logs    = parent.components.flat_map { |_n, c| c.history }.sort_by { |h| h[(params['sort'] || :time).to_sym] }
        logs    = logs.reverse unless params.include?('desc')
        offset  = params['offset'] ? params['offset'].to_i : 0
        limit   = (params['limit'] ? params['limit'].to_i : 100) + offset
        limit  -= 1 unless limit.negative?
        logs    = logs[offset..limit]
        logs    = logs.map { |log| log.only(*params['fields'].split(',').map(&:to_sym)) } if params.include?('fields')
        json_format(logs)
      end

      get '/component/:component' do
        content_type :json
        json_format(component.call_route(:get, '/'))
      end

      get '/component/:component/*' do
        content_type :json
        component.params = params
        json_format(component.call_route(:get, "/#{params['splat'].join('/')}"))
      end

      helpers do
        def parent
          Wasteland.current_server.parent
        end

        def wasteland
          Wasteland.current_server
        end

        def component
          parent.components[params['component'].to_sym] if env['PATH_INFO'] =~ /^\/component\/.*/i
        end

        def json_format(payload)
          if params.include?('pretty')
            JSON.pretty_generate(payload)
          else
            payload.to_json
          end
        end
      end
    end
  end
end
