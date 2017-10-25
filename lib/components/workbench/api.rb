module TaskVault
  class Workbench < ServerComponent

    protected

    def setup_routes
      super

      get '/recipes' do
        recipes
      end

      get '/recipes/:id' do
        if params[:id] =~ /\d+/
          recipe(params[:id].to_i)
        else
          { status: 404, message: 'Invalid ID format. Expected an integer.' }
        end
      end

      post '/recipes' do
        begin
          add(params.keys_to_sym)
        rescue => e
          { status: 500, message: "Failed to add recipe: #{e}" }
        end
      end

      post '/recipes/remove/:id' do
        if params[:id] =~ /\d+/
          remove(params[:id])
        else
          { status: 404, message: 'Invalid ID format. Expected an integer.' }
        end
      end

      # delete '/recipes/:id' do
      #   component.delete(params[:id])
      # end
    end
  end
end
