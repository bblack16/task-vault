module TaskVault
  class Workbench < ServerComponent

    protected

    def setup_routes
      super

      get '/recipes' do
        component.recipes
      end

      get '/recipes/:id' do
        component.recipes[params[:id].to_sym]
      end

      post '/recipes' do
        begin
          component.add(params.keys_to_sym)
        rescue => e
          { error: e }
        end
      end

      post '/recipes/remove/:id' do
        if params[:id].nil? || component.recipes[params[:id].to_sym].nil?
          { success: false, request: :remove, message: 'You must pass a valid task id.' }
        else
          { success: component.remove(params[:id].to_sym), request: :cancel }
        end
      end

      # delete '/recipes/:id' do
      #   if params[:id].nil? || component.recipes[params[:id].to_sym].nil?
      #     { success: false, request: :delete, message: 'You must pass a valid recipe name.' }
      #   else
      #     { success: !component.delete(params[:id].to_sym).empty?, request: :delete, id: params[:id] }
      #   end
      # end

      put '/load' do
        if params[:path]
          component.load_recipes(params[:path])
        else
          component.load_recipes
        end
      end
      
      put '/recipes/:id/save' do
        component.save(params[:id].to_sym, format: (params[:format] || :yaml).to_sym)
      end

      put 'recipes/save_all' do
        component.save_all(format: (params[:format] || :yaml).to_sym)
      end
    end
  end
end
