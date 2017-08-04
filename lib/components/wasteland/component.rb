
module TaskVault
  class Component
    attr_reader :params, :request

    def params=(params)
      @params = params.keys_to_sym
    end

    def request=(request)
      @request = request
    end

    def routes
      self.class._routes.map do |verb, paths|
        [verb, paths.keys]
      end.to_h
    end

    def call_route(verb, request, params, server)
      pattern, details = self.class._routes[verb].find { |path, _details| path.match(request.path_info) }
      return unless details && details[:block]
      self.request = request
      self.params = params.merge(pattern.params(request.path_info))
      request[:api_mode] = true if details[:api_mode]
      @route_delegate = server
      response = self.instance_eval(&details[:block])
      @route_delegate = nil
      response
    end

    def method_missing(*args, &block)
      if @route_delegate
        @route_delegate.send(*args, &block)
      else
        super
      end
    end

    # def slim(view)
    #   @route_delegate.send(:slim, "components/#{self.class.to_s.downcase.split('::').last}/#{view}".to_sym, { locals: { component: self } }, *args)
    # end

    def view_render(engine, path, klass = self.class, *args)
      @route_delegate.send(engine, "components/#{klass.to_s.sub(/^TaskVault\:\:/, '').downcase.gsub('::', '/')}/#{path}".to_sym, { locals: { component: self } }, *args)
    end

    class << self

      def _routes
        @_routes ||= _load_parent_routes
      end

      def _load_parent_routes
        @_routes = {}
        ancestors.each do |ancestor|
          next if ancestor == self || !ancestor.respond_to?(:_routes)
          ancestor._routes.each do |verb, paths|
            paths.each do |path, details|
              block = details[:block]
              if details[:api_mode]
                send("#{verb}_api", details[:sub_path], version: details[:version], &block)
              else
                send(verb, details[:sub_path], &block)
              end
            end
          end
        end
        @_routes
      end

      def base_route(api, version = 1)
        "#{api ? "/api/v#{version}" : nil}/components/#{name.downcase.split(':').last}"
      end

      def add_route(verb, path, api_mode: true, version: 1, &block)
        path = '' if path == '/'
        full_path = "#{base_route(api_mode, version)}#{path}#{verb == :get ? '(.:format)?' : nil}/?".pathify
        (_routes[verb] ||= {})[Mustermann.new(full_path)] = { block: block, api_mode: api_mode, version: version, sub_path: path }
      end

      BlockStack::VERBS.each do |verb|
        define_method(verb) do |path, &block|
          add_route(verb, path, api_mode: false, &block)
        end

        define_method("#{verb}_api") do |path, version: 1, &block|
          add_route(verb, path, api_mode: true, version: version, &block)
        end
      end
    end

    def self.assets
      @assets ||= (self == TaskVault::Component ? default_assets : ASSET_TYPES.map { |a| [a, []] }.to_h)
    end

    def self.retrieve_assets(type, *args)
      self.assets[type] || []
    end

    def self._all_views
      (retrieve_assets(:views) +
      ancestors.flat_map do |anc|
        next if self == anc || !anc.respond_to?(:_all_views)
        anc._all_views
      end).compact.uniq
    end

    def self.sprockets_paths
      (retrieve_assets(:javascript) + retrieve_assets(:stylesheets) + retrieve_assets(:images)).map { |u| u.split('/')[0..-2].join('/') }.uniq
    end

    def self.default_assets
      ASSET_TYPES.map do |type|
        [type, [File.expand_path("../app/#{type}", __FILE__)]]
      end.to_h
    end

    ASSET_TYPES = [:views, :javascript, :fonts, :stylesheets, :images]

    def self.asset_path(type, *paths)
      return unless ASSET_TYPES.include?(type)
      assets[type] = ((assets[type] || []) + paths.flatten).uniq
    end

    class << self
      ASSET_TYPES.each do |type|
        define_method("#{type}_path") do |*paths|
          asset_path(type, *paths)
        end
      end
    end

    protected


    # def _routes
    #   @_routes ||= {}
    # end
    #
    # def base_route
    #   "/components/#{name}"
    # end
    #
    # def add_route(verb, path, &block)
    #   path = '' if path == '/'
    #   full_path = "#{base_route}#{path}#{verb == :get ? '(.:format)?' : nil}/?".pathify
    #   (_routes[verb] ||= {})[Mustermann.new(full_path)] = block
    # end

    BlockStack::VERBS.each do |verb|
      define_method(verb) do |path, &block|
        # add_route(verb, path, &block)
      end
    end

    get_api '/' do
      describe
    end

    get_api '/routes' do
      routes
    end

    get_api '/settings' do
      serialize
    end

    put_api '/settings' do
      params.each do |k, v|
        send("#{k}=", *[v].flatten(1)) if respond_to?("#{k}=")
      end
      serialize
    end

    get_api '/logs' do
      process_component_logs(history, params)
    end

    get_api '/message_queue' do
      message_queue
    end

    [:start, :stop, :restart].each do |cmd|
      put_api "/#{cmd}" do
        { cmd => send(cmd) }
      end
    end

  end
end
