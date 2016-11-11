# frozen_string_literal: true
require 'reactrb'
require 'sinatra/base'
require 'opal-browser'

module TaskVault
  class Overseer
    class Server < Sinatra::Base
      @parent = nil
      set :root, File.dirname(__FILE__)
      enable :sessions

      def self.prefix
        @prefix ||= '/assets'
      end

      def self.maps_prefix
        @maps_prefix ||= '/__OPAL_SOURCE_MAPS__'
      end

      def self.maps_app
        @maps_app ||= Opal::SourceMapServer.new(sprockets, maps_prefix)
      end

      def self.opal
        @opal ||= Opal::Server.new do |s|
          s.append_path File.expand_path('../app/javascript', __FILE__)
          s.append_path File.expand_path('../app', __FILE__)
          s.main = File.expand_path('../app/javascript/application', __FILE__)
        end
      end

      # get TaskVault::Overseer::Server.opal.sprockets.source_maps.prefix do
      #   opal.source_maps.call(env)
      # end

      get maps_prefix do
        # ::Opal::Sprockets::SourceMapHeaderPatch.inject!(maps_prefix)
        maps_app.call(maps_prefix)
      end

      get '/assets/*' do
        env['PATH_INFO'].sub!('/assets', '')
        TaskVault::Overseer::Server.opal.sprockets.call(env)
      end

      get '/fonts/*' do
        redirect env['PATH_INFO'].sub('fonts', 'assets/fonts')
      end

      Opal.use_gem 'dformed'
      def self.precompile!
        # puts File.expand_path('../app/javascript/application.js', __FILE__)
        # Opal.append_path File.expand_path('../app', __FILE__)
        # Opal.append_path File.expand_path('../app/javascript', __FILE__)
        # puts Opal::Builder.build('application').to_s
        # Opal::Builder.build('application').to_s.to_file(File.expand_path('../app/javascript/application.js', __FILE__))
        # BBLib.scan_dir(settings.public_folder).each do |file|
          FileUtils.rm_rf(settings.public_folder)
        # end
        environment = TaskVault::Overseer::Server.opal.sprockets
        manifest = Sprockets::Manifest.new(environment.index, settings.public_folder)
        manifest.compile(%w(*.css application.rb javascript/*.js *.png *.jpg *.svg *.eot *.ttf *.woff *.woff2))
      end

      class << self
        attr_accessor :parent, :root
      end

      helpers do
        IMAGE_TYPES = [:svg, :png, :jpg, :jpeg, :gif].freeze

        def parent
          TaskVault::Overseer::Server.parent
        end

        def asset_prefix
          '/assets/'
        end

        def app_location
          File.expand_path('../app', __FILE__)
        end

        def javascript_tag(path, type: 'text/javascript')
          path = asset_prefix + 'javascript/' + path
          "<script type='#{type}' src='#{path}'></script>"
        end

        def image_tag(image, *fallbacks, recursive: true, style: '')
          path = nil
          image_dir = app_location + '/images/'
          IMAGE_TYPES.each do |type|
            next if path
            matches = BBLib.scan_files(image_dir, "#{image}.#{type}", recursive: recursive)
            next if matches.empty?
            path = matches.first.sub(app_location, '/assets')
          end
          if path
            "<img src='#{path}' style='#{style}'></img>"
          elsif fallbacks.empty?
            nil
          else
            fallbacks.find { |f| image_tag(f, recursive: recursive, style: style) }
          end
        end

        def component name = nil
          name = env['PATH_INFO'].scan(/(?<=\/component\/).*?(?=\/|$)/).first.to_s.to_sym unless name
          parent.components[name.to_sym]
        end

      end

      get '/' do
        slim :index
      end

      get '/tasks' do
        slim :tasks
      end

      get '/task/:id' do
        slim :task
      end

      get '/add_task' do
        slim :add_task
      end

      get '/cancel/:id' do
        slim :cancel
      end

      get '/logs' do
        slim :logs
      end

      get '/logs.json' do
        content_type :json
        @parent.components.map { |_n, c| c.history }.flatten.to_json
      end

      get '/processes' do
        slim :processes
      end

      get '/metric/:type' do
        content_type :json
        case params[:type]
        when 'cpu'
          { value: BBLib::OS.cpu_used_p }
        when 'memory', 'mem'
          { value: BBLib::OS.mem_used_p }
        else
          { value: 0 }
        end.to_json
      end

      # get '/component/:name' do
      #   if parent.components[params[:name].to_sym]
      #     @name = params[:name]
      #     @component = parent.components[@name.to_sym]
      #     @stats = {
      #       class: @component.class,
      #       uptime: @component.uptime.to_f.to_duration,
      #       running: @component.running?
      #     }
      #     slim 'component/status'.to_sym
      #   else
      #     session[:params] = { alert: { message: "No component by the name of #{params[:name]} could be located.", title: 'Component Not Found', severity: :error } }
      #     redirect(back)
      #   end
      # end
      #
      post '/component/cmd/:name/:cmd' do
        content_type :json
        cmds = %w(start stop restart)
        if !cmds.include?(params[:cmd])
          { severity: :warning, message: "#{params[:cmd]} cannot be run.", title: 'Commnd Failed' }
        elsif component = parent.components[params[:name].to_sym]
          if component.send(params[:cmd])
            { severity: :success, message: "#{params[:cmd]} of #{params[:name]} was successful.", title: params[:cmd].to_s }
          else
            { severity: :error, message: "#{params[:cmd]} of #{params[:name]} failed.", title: "#{params[:cmd]} Failed" }
          end
        else
          { severity: :warning, message: "#{params[:name]} not found!", title: 'Command Failed' }
        end.to_json
      end

      get '/widget/:name' do
        slim "widgets/#{params[:name]}".to_sym, layout: false
      end

      get '/api/components' do
        content_type :json
        parent.components.map do |name, component|
          component.serialize.merge(name: name, running: component.running?, uptime: component.uptime)
        end.to_json
      end

      get '/api/status' do
        content_type :json
        parent.status.to_json
      end

      get '/api/health' do
        content_type :json
        { health: parent.health }.to_json
      end

      # get '/add_route/:route' do
      #   TaskVault::Overseer::Server.get "/#{params[:route]}" do
      #     "Hi, I'm a new route!"
      #   end
      #   'Added new route: ' + params[:route]
      # end

      # get '/api/component/:name/*' do
      #   path = env['PATH_INFO'].sub("/api/component/#{params[:name]}", '')
      #   component = parent.components[params[:name].to_sym]
      #
      # end

      def self.refresh_routes!
        @parent.components.each do |name, component|
          p "#{name}"
          component.map_apis(TaskVault::Overseer::Server, name)
        end
      end

      get '/routes' do
        content_type :json
        TaskVault::Overseer::Server.routes["GET"].map do |route|
          route[0]
        end.to_json
      end

    end

  end
end
