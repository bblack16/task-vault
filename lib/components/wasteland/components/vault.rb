require_relative 'task'

module TaskVault
  class Vault < ServerComponent

    # after :register_task_routes, :add, send_value: true

    def self.extract_task_route(route)
      path  = route.split(/(?<=[^^])\/(?=[^$])/)
      index = path.index('tasks') + 2
      "/#{path[index..-1].join('/')}"
    end

    protected

    # def register_task_routes(task)
    #   task.register_routes
    # end

    def setup_routes
      super

      get '/tasks' do
        if params[:fields]
          component.task_list(*params[:fields].split(',').map(&:to_sym))
        else
          component.task_list(
              :id, :name, :class, :status, :start_at, :weight, :run_count, :run_limit, :priority,
              :initial_priority, :timeout, :repeat
            )
        end
      end

      get '/tasks/:id' do
        component.find(params[:id].to_i).describe
      end

      get '/tasks/:id/settings' do
        component.find(params[:id].to_i).serialize
      end

      post '/tasks/:id/settings' do
        task = component.find(params[:id].to_i)
        params.map do |k, v|
          if task.respond_to?("#{k}=")
            task.send("#{k}=", *[v].flatten(1))
            [k, task.send(k)]
          else
            [k, nil]
          end
        end.to_h
      end

      get '/tasks/:id/logs' do
        process_component_logs(component.find(params[:id].to_i).history)
      end

      post '/tasks/add' do
        begin
          component.add(params.keys_to_sym)
        rescue => e
          { error: e }
        end
      end

      post '/tasks/cancel/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :cancel, message: 'You must pass a valid task id.' }
        else
          { success: component.cancel(params[:id].to_i), request: :cancel }
        end
      end

      post '/tasks/rerun/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :rerun, message: 'You must pass a valid task id.' }
        else
          { success: component.rerun(params[:id].to_i), request: :rerun }
        end
      end

      delete '/tasks/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :delete_task, message: 'You must pass a valid task id.' }
        else
          { success: !component.delete(params[:id].to_i).empty?, request: :delete_task, id: params[:id] }
        end
      end

      get '/queues' do
        component.tasks.map do |q, tasks|
          [q, tasks.map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }]
        end.to_h.merge(
          {
            weight: {
              limit: component.limit,
              running: component.running_weight,
              percent: component.running_weight.to_f / component.limit.to_f
            }
          }
        )
      end

      get '/queues/:queue' do
        component.tasks[params[:queue].to_sym].map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }
      end

      get '/registry' do
        component.class.registry
      end

      get '/tasks/:id/*' do
        component.find(params[:id].to_i).call_route(:get, TaskVault::Vault.extract_task_route(request.path_info), params)
      end
    end
  end
end
