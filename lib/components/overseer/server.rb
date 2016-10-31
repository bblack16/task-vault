# require 'hyper-react'
require 'reactrb'
require 'sinatra/base'
require 'opal-browser'

module TaskVault

  class Overseer::Server < Sinatra::Base
    @@parent = nil
    set :static, true                             # set up static file routing
    # set :public_folder, 'D:/test/test' # set up the static dir (with images/js/css inside)
    # set :views,  File.expand_path('../views', __FILE__) # set up the views dir
    # set :environment, Sprockets::Environment.new
    set :bind, '0.0.0.0'
    set :root, File.dirname(__FILE__)

    def self.sprockets
      @@sprockets ||= Opal::Server.new {|s|
        s.append_path File.expand_path('../app', __FILE__)
        # s.main = 'application'
      }.sprockets
    end

    def self.prefix
      @@prefix ||= '/assets'
    end

    # @prefix      = '/assets' #File.expand_path('../assets', __FILE__)
    maps_prefix = '/__OPAL_SOURCE_MAPS__'
    maps_app    = Opal::SourceMapServer.new(sprockets, maps_prefix)

    # Monkeypatch sourcemap header support into sprockets
    ::Opal::Sprockets::SourceMapHeaderPatch.inject!(maps_prefix)

    get maps_prefix do
      maps_app.call(maps_prefix)
    end

    get '/assets/*' do
      env["PATH_INFO"].sub!("/assets", "")
      @@sprockets.call(env)
    end

    BBLib.scan_files(File.expand_path('../public', __FILE__)).each do |file|
      puts file
      FileUtils.rm(file)
    end
    # FileUtils.rm_rf(File.expand_path('../public', __FILE__))
    environment = TaskVault::Overseer::Server.sprockets
    manifest = Sprockets::Manifest.new(environment.index, File.expand_path('../public', __FILE__))
    manifest.compile(%w(application.rb app.css *.rb *.png *.jpg *.svg *.eot *.ttf *.woff *.woff2))

    def self.parent= parent
      @@parent = parent
    end

    def self.parent
      @@parent
    end

    get '/' do
      slim :index
      # <<-HTML
      #   <!doctype html>
      #   <html>
      #     <head>
      #       <title>Hello React</title>
      #       #{::Opal::Sprockets.javascript_include_tag('application', sprockets: sprockets, prefix: prefix, debug: true)}
      #     </head>
      #     <body>
      #       <div id="content">Yo, I think this be working man!</div>
      #     </body>
      #   </html>
      # HTML
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
      slim :restart
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

  end

end
