module TaskVault
  class Vault < ServerComponent

    protected

    def setup_routes
      super
      get '/tasks' do
        if params['fields']
          task_list(*params['fields'].split(',').map(&:to_sym))
        else
          task_list
        end
      end
    end
  end
end
