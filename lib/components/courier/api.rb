module TaskVault
  class Courier < ServerComponent

    protected

    def setup_routes
      super

      get '/handlers' do
        count = -1
        component.message_handlers.map { |handler| [count += 1, handler.describe] }.to_h
      end

      get '/handlers/:id' do
        component.message_handlers[params[:id].to_i].describe
      end

      post '/handlers/add' do
        begin
          component.add(params.keys_to_sym)
        rescue => e
          { error: e }
        end
      end

      get '/handlers_list' do
        component.list
      end

      post '/save' do
        if params[:id].nil? || component.find(params[:id].to_sym).nil?
          { success: false, request: :save_handler, message: 'You must pass a valid handler id.' }
        else
          { success: component.save(params[:id].to_sym), request: :save_handler }
        end
      end

      put '/save_all' do
        { success: component.save_all, request: :save_all_handlers }
      end

      delete '/handlers' do
        if params[:id].nil? || component.message_handlers(params[:id].to_sym).nil?
          { success: false, request: :delete_handler, message: 'You must pass a valid handler name.' }
        else
          { success: !component.remove(params[:id].to_sym).empty?, request: :delete_handler, id: params[:id] }
        end
      end

      put '/reload' do
        component.reload
      end

      get '/registry' do
        component.class.registry
      end

    end
  end
end
