

module TaskVault

  class Overseer::Server < Sinatra::Base
    @@parent = nil

    def self.parent= parent
      @@parent = parent
    end

    def self.parent
      @@parent
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

  end

end
