require 'slim'
module TaskVault
  class Component < BBLib::LazyClass

    def self.add_api verb, route, opts = {}, &block
      apis["api_#{verb} #{route}"] = { type: :api, verb: verb, route: route, opts: opts, block: block }
    end

    def self.add_route verb, route, opts = {}, &block
      apis["#{verb} #{route}"] = { type: :route, verb: verb, route: route, opts: opts, block: block }
    end

    def self.get route, opts = {}, &block
      add_route :get, route, opts, &block
    end

    def self.post route, opts = {}, &block
      add_route :post, route, opts, &block
    end

    def self.get_api route, opts = {}, &block
      add_api :get, route, opts, &block
    end

    def self.post_api route, opts = {}, &block
      add_api :post, route, opts, &block
    end

    def self.slim path, scope
      Slim::Template.new(File.expand_path("../vault/views/#{path}.slim", __FILE__)).render(scope)
    end

    def self.apis
      @apis ||= {}
    end

    def apis
      ancestor = self.class.ancestors[1]&.apis || {}
      ancestor.merge(self.class.apis)
    end

    def map_apis server, name
      self.apis.each do |route, data|
        server.send(data[:verb], build_route(data[:route], name, data[:type]), data[:opts], &data[:block])
      end
    end

    def self.views
      @views ||= File.expand_path('../views', __FILE__)
    end

    def self.set_views path
      @views = path
    end

    def component_views
      self.class.views
    end

    def build_route route, name, type = :api
      case type
      when :api
        "/api/component/#{name}/#{route}".pathify
      when :route
        "/component/#{name}/#{route}".pathify
      end
    end

    get '/logs' do
      @component = component
      slim "component/logs".to_sym
    end

    get_api '/logs' do
      content_type :json
      component.history.to_json
    end

    get_api '/status' do
      content_type :json
      component = component
      {
        running: component.running?,
        class: component.class,
        uptime: component.uptime,
        started: component.started,
        stopped: component.stopped
      }.merge(component.serialize).to_json
    end

    get_api '/settings' do
      content_type :json
      component = component
      component.class.attrs.map do |method, data|
        [method, data.merge(value: component.send(method))]
      end.to_h.to_json
    end

  end

end
