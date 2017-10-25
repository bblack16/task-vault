module TaskVault
  class Inventory < ServerComponent

    protected

    def setup_routes
      get '/' do
        describe.merge(items: items.size, access_count: access_counter)
      end

      get '/status' do
        {
          capacity:     capacity,
          items:        items.size,
          percent:      percent,
          access_count: access_counter
        }
      end

      get '/items' do
        items.map do |item|
          {
            key: item.key,
            class: item.value.class,
            access_count: item.access_counter,
            preview: BBLib.chars_up_to(item.value, 50),
            description: item.description
          }
        end
      end

      get '/items/find' do
        find_item(params.except(:captures, :component, :splat, :format).keys_to_sym)&.details
      end

      get '/items/find_all' do
        find_all_items(params.except(:captures, :component, :splat, :format).keys_to_sym).map(&:details)
      end

      get '/items/:key' do
        find_item(params[:key])&.details
      end
    end

  end
end
