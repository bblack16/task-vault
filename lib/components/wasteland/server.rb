module TaskVault
  class Wasteland < ServerComponent
    class Server < Sinatra::Base

      before do
        Wasteland.wasteland.queue_verbose("Processing request: #{request.request_method} #{request.path_info} (#{request.ip} - #{request.user_agent})")
        if params[:format] == 'yaml'
          content_type :yaml
        elsif params[:format] != 'html'
          content_type :json
        end
      end

      after do
        return if response['Content-Type'] == 'text/html;charset=utf-8'
        if response.body.is_a?(Hash) && response.body[:status] && response.body[:status].is_a?(Fixnum)
          status response.body[:status]
        end
        if params[:format] == 'yaml'
          response.body = response.body.to_yaml
        elsif params[:format] == 'html'
          response.body = html_format(response.body)
        else
          response.body = json_format(response.body)
        end
      end

      def self.route_names(verb)
        return [] unless routes[verb.to_s.upcase]
        routes[verb.to_s.upcase].map { |r| r[0].to_s }
      end

      def self.remove_route(verb, path)
        Wasteland.wasteland.queue_verbose("Removing a route from Wasteland: #{verb.to_s.upcase} #{path}")
        routes[verb.to_s.upcase].delete_if { |r| r[0].to_s == path }
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

      put '/reboot' do
        parent.stop
        TaskVault::Server.reboot(2)
      end

      get '/components' do
        parent.components.map { |v| [v.name, v.class.to_s] }.to_h
      end

      get '/logs' do
        logs = parent.components.flat_map(&:history)
        process_component_logs(logs)
      end

      error Sinatra::NotFound do
        types = %w(scavengers raiders adventurers wanderers vault-dwellers)
        { status: 404, message: "The Wasteland is vast and expansive, but #{types.sample} have not yet located that resource." }
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
          parent.component(component.to_sym) if request.path_info =~ /^\/components\/.*/i
        end

        def path_ids
          request.path_info.scan(/(?<=\/)\d+(?=\/)/).map(&:to_i)
        end

        def path_id
          path_ids.first
        end

        def json_format(payload)
          if params.include?(:pretty)
            JSON.pretty_generate(payload)
          else
            payload.to_json
          end
        end

        def html_format(payload)
          payload.to_s
        end

        def process_component_logs(logs)
          logs    = logs.sort_by { |h| h[(params[:sort] || :time).to_sym] }
          logs    = logs.reverse unless params.include?('desc')
          offset  = params[:offset] ? params[:offset].to_i : 0
          limit   = (params[:limit] ? params[:limit].to_i : 100) + offset
          limit  -= 1 unless limit.negative?
          logs    = logs[offset..limit]
          logs    = logs.map { |log| log.only(*params[:fields].split(',').map(&:to_sym)) } if params.include?('fields')
          if params[:events]
            events = params[:events].split(',').map(&:to_sym)
            logs = logs.select { |log| log[:event].is_a?(Array) ? log[:event].any? { |e| events.include?(e) } : events.include?(log[:event]) }
          end
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
