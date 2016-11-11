module TaskVault
  class Vault

    set_views File.expand_path('../views', __FILE__)

    get '/' do
      @component = component
      slim 'vault/index'.to_sym
    end

    get '/tasks' do
      content_type :json
      if component = parent.components[params[:name].to_sym]
        if component.is_a?(TaskVault::Vault)
          component.all_tasks.map(&:serialize)
        else
          { severity: :warning, message: "#{params[:name]} is not a vault", title: 'Wrong Class' }
        end
      else
        { severity: :warning, message: "#{params[:name]} not found.", title: 'Not found' }
      end.to_json
    end

    get '/queue/:queue' do
      content_type :json
      if component = parent.components[params[:name].to_sym]
        if component.is_a?(TaskVault::Vault)
          component.tasks[params[:queue].to_sym]&.map(&:serialize)
        else
          { severity: :warning, message: "#{params[:name]} is not a vault", title: 'Wrong Class' }
        end
      else
        { severity: :warning, message: "#{params[:name]} not found.", title: 'Not found' }
      end.to_json
    end

    get '/queues' do
      content_type :json
      if component = parent.components[params[:name].to_sym]
        if component.is_a?(TaskVault::Vault)
          component.tasks.map { |name, tasks| [name, tasks.size] }.to_h
        else
          { severity: :warning, message: "#{params[:name]} is not a vault", title: 'Wrong Class' }
        end
      else
        { severity: :warning, message: "#{params[:name]} not found.", title: 'Not found' }
      end.to_json
    end

  end
end
