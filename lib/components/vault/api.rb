
module TaskVault
  class Vault < ServerComponent

    views_path File.expand_path('../app/views', __FILE__)

    get '/' do
      view_render :slim, :index
    end

    # def routes
      # task_routes = {}
      # all_tasks.each { |task| task_routes = task_routes.merge(task.routes) }
      # super.merge(task_routes)
    # end

    def self.retrieve_assets(type, *args)
      assets[type] + TaskVault::Task.descendants.flat_map { |d| d.retrieve_assets(type, *args) }
    end

    get_api '/' do
      describe.merge(tasks: all_tasks.size)
    end

    get_api '/tasks' do
      if params[:fields]
        task_list(*params[:fields].split(',').map(&:to_sym))
      else
        task_list(
            :id, :name, :class, :status, :start_at, :weight, :run_count, :run_limit, :priority,
            :initial_priority, :timeout, :repeat
          )
      end
    end

    post_api '/tasks' do
      begin
        add(params.keys_to_sym)
      rescue => e
        { status: 500, message: e }
      end
    end

    get_api '/queues' do
      tasks.map do |q, tasks|
        [q, tasks.map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }]
      end.to_h.merge(
        {
          weight: {
            limit: limit,
            running: running_weight,
            percent: running_weight.to_f / component.limit.to_f
          }
        }
      )
    end

    get_api '/queues/:queue' do
      tasks[params[:queue].to_sym].map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }
    end

    get_api '/registry' do
      self.class.registry
    end

    BlockStack::VERBS.each do |verb|
      send("#{verb}_api", '/tasks/:id/?*') do
        task = find(params[:id].to_i) if params[:id] =~ /^\d+$/
        task = find_by(name: params[:id]) unless task
        if task
          task.call_route(verb, request, params, @route_delegate)
        else
          { status: 404, message: "I've scavenged the Wasteland for that task. Alas, it does not exist!" }
        end
      end
    end

    get '/tasks/:id/?*' do
      task = find(params[:id].to_i) if params[:id] =~ /^\d+$/
      task = find_by(name: params[:id]) unless task
      if task
        task.call_route(:get, request, params, @route_delegate)
      else
        { status: 404, message: "I've scavenged the Wasteland for that task. Alas, it does not exist!" }
      end
    end
  end
end
