module TaskVault
  class Inventory < ServerComponent

    protected

    def setup_routes
      get '/status' do
        {
          capacity: component.capacity,
          items: component.items.size,
          percent: component.percent,
          access_count: component.access_counter
        }
      end

      get '/items' do
        component.items.map(&:details)
      end

      get '/items/find' do
        component.find_item(params.reject { |k,v| k == :captures }.keys_to_sym)&.details
        # params.reject { |k,v| k == :captures }.keys_to_sym
      end

      get '/items/find_all' do
        component.find_all_items(params.reject { |k,v| k == :captures }.keys_to_sym).map(&:details)
      end

      get '/items/:key' do
        component.find_item(params[:key])&.details
      end
    end

  end
end
