module TaskVault
  class Wasteland < ServerComponent
    class Server < BlockStack::UiServer
      disable :traps

      def self.sprocket_paths
        TaskVault::Component.descendants.flat_map { |c| c.sprockets_paths }.uniq
      end

      def self.component_views
        @component_views ||= TaskVault::Component.descendants.flat_map { |c| c.retrieve_assets(:views) }.uniq + assets[:views]
      end

      views_path(File.expand_path('../app/views', __FILE__))

      get_api '/api/v1/' do
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

      get_api '/api/v1/routes' do
        p 'ROOOUUUTES'
        base = BlockStack::VERBS.each_with_object({}) { |v, h| h[v] = Server.route_names(v).sort }
        comp_routes = {}
        parent.components.each do |comp|
          comp_routes = comp_routes.deep_merge(comp.routes, merge_arrays: true)
        end
        comp_routes.deep_merge(base, merge_arrays: true).hmap { |verb, routes| [verb, routes.map(&:to_s).sort] }
      end

      get_api '/api/v1/health' do
        { health: parent.health }
      end

      get_api '/api/v1/status' do
        parent.status
      end

      [:start, :stop, :restart].each do |cmd|
        put_api "/api/v1/#{cmd}" do
          { cmd => parent.send(cmd) }
        end
      end

      put_api '/api/v1/reboot' do
        parent.stop
        TaskVault::Server.reboot(2)
      end

      get_api '/api/v1/components' do
        parent.components.map { |v| [v.name, v.class.to_s] }.to_h
      end

      get_api '/api/v1/logs' do
        logs = parent.components.flat_map(&:history)
        self.class.process_component_logs(logs)
      end

      get '/components/:component/?*' do
        response = component.call_route(:get, request, params, self)
        raise Sinatra::NotFound unless response
        response
      end

      get_api '/api/v:version/components/:component/?*' do
        response = component.call_route(:get, request, params, self)
        raise Sinatra::NotFound unless response
        response
      end

      error Sinatra::NotFound do
        types = %w(scavengers raiders adventurers wanderers)
        { status: 404, message: "The Wasteland is vast and expansive, but #{types.sample} have not yet located that resource." }
      end

      helpers do
        def find_template(_views, name, engine, &block)
          if component
            views = component.class._all_views
          else
            views = self.class.component_views.uniq
          end
          super(views, name, engine, &block)
        end

        def build_menu
          menu(env)
        end

        def menu(env)
          {
            title: title(env),
            main_menu: main_menu(env)
          }
        end

        def title(env)
          'TaskVault'
        end

        def main_menu(env)
          {
            home: {
              text: 'Home',
              href: '/',
              title: 'Head home.',
              tooltip: 'true',
              'data-placement': 'right',
              'data-animation': 'true',
              'data-replace': "true",
              active_when: [
                '/'
              ]
            },
            components: {
              text: 'Components',
              active_when: [
                '/components'
              ],
              sub: parent.components.map { |c| [c.name, { href: "/components/#{c.name}" }] }.to_h
            },
            examples: {
              text: 'Examples',
              href: '/examples',
              title: 'Examples of elements available in BlockStack UI',
              'data-placement': 'right',
              'data-animation': 'true',
              'data-replace': "true",
              active_when: [
                '/examples'
              ]
            }
          }
        end

        def parent
          Wasteland.current_server.parent
        end

        def wasteland
          Wasteland.current_server
        end

        def component
          component = (params[:component] || request.path_info.split('/')[2]).split('.').first
          parent.component(component.to_sym)
        rescue StandardError
          nil
        end

        def process_component_logs(logs, params = {})
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
          if params.include?(:log_format)
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
