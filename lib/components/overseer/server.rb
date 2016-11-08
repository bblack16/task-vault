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

      def self.sprockets
        @sprockets ||= Opal::Server.new do |s|
          s.append_path File.expand_path('../app', __FILE__)
          s.append_path File.expand_path('../app/javascript', __FILE__)
          s.append_path File.expand_path('../app/javascript/vendor', __FILE__)
          s.append_path File.expand_path('../app/stylesheets', __FILE__)
          s.append_path File.expand_path('../app/stylesheets/vendor', __FILE__)
          s.append_path File.expand_path('../app/fonts', __FILE__)
          s.main = 'application'
        end.sprockets
      end

      def self.prefix
        @prefix ||= '/assets'
      end

      def self.maps_prefix
        @maps_prefix ||= '/__OPAL_SOURCE_MAPS__'
      end

      def self.maps_app
        @maps_app ||= Opal::SourceMapServer.new(sprockets, maps_prefix)
      end

      Opal.use_gem 'dformed'

      get maps_prefix do
        ::Opal::Sprockets::SourceMapHeaderPatch.inject!(maps_prefix)
        maps_app.call(maps_prefix)
      end

      get '/assets/*' do
        env['PATH_INFO'].sub!('/assets', '')
        TaskVault::Overseer::Server.sprockets.call(env)
      end

      get '/fonts/*' do
        redirect env['PATH_INFO'].sub('fonts', 'assets/fonts')
      end

      def self.precompile!
        BBLib.scan_dir(File.expand_path('../public', __FILE__)).each do |file|
          FileUtils.rm_rf(file)
        end
        environment = TaskVault::Overseer::Server.sprockets
        manifest = Sprockets::Manifest.new(environment.index, File.expand_path('../public', __FILE__))
        manifest.compile(%w(*.css application.rb javascript/*.js *.png *.jpg *.svg *.eot *.ttf *.woff *.woff2))
      end

      def self.parent=(parent)
        @parent = parent
      end

      def self.parent
        @parent
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

      get '/start/:name' do
        slim :start
      end

      get '/stop/:name' do
        slim :stop
      end

      get '/restart/:name' do
        severity = :success
        if component = parent.components.find { |k, _| k == params[:name].to_sym }
          component = component[1]
          if component.restart
            msg = "Successfully restarted #{params[:name]}"
          else
            msg = "Failed to restart #{params[:name]}"
            severity = :warning
          end
        else
          msg = "No component by the name of #{params[:name]} found."
          severity = :error
        end
        session[:params] = { alert: { message: msg, severity: severity, title: 'Restart' } }
        redirect(back)
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

      get '/component/:name' do
        if parent.components[params[:name].to_sym]
          @name = params[:name]
          @component = parent.components[@name.to_sym]
          @stats = {
            class: @component.class,
            uptime: @component.uptime.to_f.to_duration,
            running: @component.running?
          }
          slim 'component/status'.to_sym
        else
          session[:params] = { alert: { message: "No component by the name of #{params[:name]} could be located.", title: 'Component Not Found', severity: :error } }
          redirect(back)
        end
      end

      get '/component/:name/logs' do
        if parent.components[params[:name].to_sym]
          @name = params[:name]
          @component = parent.components[@name.to_sym]
          @logs = @component.history
          slim 'component/logs'.to_sym
        else
          session[:params] = { alert: { message: "No component by the name of #{params[:name]} could be located.", title: 'Component Not Found', severity: :error } }
          redirect(back)
        end
      end

      ATTR_FIELDS = {
        int: :number,
        int_between: :number,
        float: :number,
        string: :text,
        array: :textarea,
        array_of: :textarea,
        hash: :textarea
      }.freeze

      get '/component/:name/settings' do
        if parent.components[params[:name].to_sym]
          @name = params[:name]
          @component = parent.components[@name.to_sym]
          @current = @component.serialize
          @settings = @component.class.attrs
          fields = @settings.flat_map do |name, data|
            unless [:reader].any? { |i| data[:type] == i }
              DFormed::ElementBase.create(type: :label, label: name.to_s.title_case)
              DFormed::ElementBase.create(type: ATTR_FIELDS[data[:type]] || :text, name: name, value: @component.send(name))
            end
          end.compact
          @form = DFormed::VerticalForm.new(name: 'settings', fields: fields)
          slim 'component/settings'.to_sym
        else
          session[:params] = { alert: { message: "No component by the name of #{params[:name]} could be located.", title: 'Component Not Found', severity: :error } }
          redirect(back)
        end
      end

      get '/widget/:name' do
        slim "widgets/#{params[:name]}".to_sym, layout: false
      end

      get '/components' do
        content_type :json
        parent.components.map do |name, component|
          component.serialize.merge(name: name, running: component.running?, uptime: component.uptime)
        end.to_json
      end

    end
  end
end
