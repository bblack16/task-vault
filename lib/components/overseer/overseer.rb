
module TaskVault
  class Overseer < Component
    attr_int_between 0, nil, :port, default: 4567, serialize: true, always: true
    attr_str :bind, default: '0.0.0.0', serialize: true, always: true
    attr_str :path, default: Dir.pwd, allow_nil: true, serialize: true, always: true
    attr_reader :server

    def start
      queue_msg("Starting Overseer on #{@bind}:#{@port}.", severity: :info)
      super
    end

    def stop
      queue_msg("Stopping Overseer running at #{@bind}:#{@port}.", severity: :info)
      Server.quit!
      super
    end

    def path= path
      @path = "#{path}/overseer".pathify
    end

    protected

    def run
      Server.parent = @parent
      create_dirs
      setup_assets
      Server.set port: @port, bind: @bind, root: @path, public_dir: "#{@path}/public"
      Server.precompile!
      Server.refresh_routes!
      Server.run!
    end

    def create_dirs
      FileUtils.mkpath(@path) unless Dir.exist?(@path)
      ['views', 'app/javascript', 'app/stylesheets', 'app/images'].each do |pth|
        path = "#{@path}/#{pth}"
        p path
        FileUtils.mkpath(path) unless Dir.exist?(path)
      end
    end

    def setup_assets
      FileUtils.cp_r(File.expand_path('../views', __FILE__), @path)
      FileUtils.cp_r(File.expand_path('../app', __FILE__), @path)
      @parent.components.merge(__comp: Component.new).each do |name, component|
        klass = component.class.to_s.sub('TaskVault::', '').downcase
        FileUtils.cp_r(component.component_views, "#{@path}/views/#{klass}") if Dir.exist?(component.component_views)
      end
    end

  end
end

require_relative 'server'
require_relative 'apis/component_api'
require_relative 'apis/vault/vault'
