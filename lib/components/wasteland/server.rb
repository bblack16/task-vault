module TaskVault
  class Wasteland < ServerComponent
    class Server < Sinatra::Base

      before do
        if params[:format] == 'yaml'
          content_type :yaml
        else
          content_type :json
        end
      end

      after do
        return if response["Content-Type"] == "text/html;charset=utf-8"
        if params[:format] == 'yaml'
          response.body = response.body.to_yaml
        else
          response.body = json_format(response.body)
        end
      end

      def self.route_names(verb)
        return [] unless routes[verb.to_s.upcase]
        routes[verb.to_s.upcase].map { |r| r[0].to_s }
      end

      get '/' do
        {
          message: "Welcome to Wasteland VERSION #{Wasteland::VERSION}",
          wasteland: {
            version: Wasteland::VERSION,
            ip_address: settings.bind
          },
          health: parent.health,
          status: parent.status
        }
      end

      get '/routes' do
        [:get, :post, :delete, :put].each_with_object({}) { |v, h| h[v] = Server.route_names(v).sort }
      end

      get '/health' do
        { health: parent.health }
      end

      get '/status' do
        parent.status
      end

      [:start, :stop, :restart].each do |cmd|
        put "/#{cmd}" do
          { cmd => parent.send(cmd) }
        end
      end

      get '/components' do
        parent.components.map { |k, v| [k, v.class.to_s] }.to_h
      end

      get '/components/logs' do
        logs = parent.components.flat_map { |_n, c| c.history }
        process_component_logs(logs)
      end

      helpers do
        def parent
          Wasteland.current_server.parent
        end

        def wasteland
          Wasteland.current_server
        end

        def component
          component = params[:component] || request.path_info.split('/')[2]
          parent.components[component.to_sym] if request.path_info =~ /^\/components\/.*/i
        end

        def json_format(payload)
          if params.include?(:pretty)
            JSON.pretty_generate(payload)
          else
            payload.to_json
          end
        end

        def process_component_logs(logs)
          logs    = logs.sort_by { |h| h[(params[:sort] || :time).to_sym] }
          logs    = logs.reverse unless params.include?('desc')
          offset  = params[:offset] ? params[:offset].to_i : 0
          limit   = (params[:limit] ? params[:limit].to_i : 100) + offset
          limit  -= 1 unless limit.negative?
          logs    = logs[offset..limit]
          logs    = logs.map { |log| log.only(*params[:fields].split(',').map(&:to_sym)) } if params.include?('fields')
          if params.include?('log_format')
            logs = logs.map do |log|
              line = params[:log_format].dup
              log.each do |k, v|
                line = line.gsub("{{#{k}}}", v.to_s).gsub("{{#{k.to_s.upcase}}}", v.to_s.upcase)
              end
              line.gsub(/\{\{.*?\}\}/, '')
            end
          end
          logs
        end
      end
    end
  end
end
