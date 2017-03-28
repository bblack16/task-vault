require_relative 'task_api'

module TaskVault
  class Vault < ServerComponent

    def self.extract_task_route(route)
      path  = route.split(/(?<=[^^])\/(?=[^$])/)
      index = path.index('tasks') + 2
      "/#{path[index..-1].join('/')}"
    end

    def self._task_not_found
      { status: 404, message: 'The requested task does not exist.' }
    end

    protected

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
        task = component.find(params[:id].to_i) if params[:id] =~ /^\d+$/
        task = component.find_by(name: params[:id]) unless task
        if task
          task.describe
        else
          TaskVault::Vault._task_not_found
        end
      end

      get '/tasks/:id/settings' do
        task = component.find(params[:id].to_i) if params[:id] =~ /^\d+$/
        task = component.find_by(name: params[:id]) unless task
        if task
          task.serialize
        else
          TaskVault::Vault._task_not_found
        end
      end

      post '/tasks/:id/settings' do
        task = component.find(params[:id].to_i) if params[:id] =~ /^\d+$/
        task = component.find_by(name: params[:id]) unless task
        if task
          JSON.parse(request.body.read).map do |k, v|
            if task.respond_to?("#{k}=")
              task.send("#{k}=", *[v].flatten(1))
              task.queue_debug("Changed method #{k} via Wasteland to #{BBLib.chars_up_to(v, 20, '... (first 20)')}. Request from #{request.ip}.", event: :audit)
              [k, task.send(k)]
            else
              [k, nil]
            end
          end.to_h
        else
          TaskVault::Vault._task_not_found
        end
      end

      get '/tasks/:id/logs' do
        task = component.find(params[:id].to_i) if params[:id] =~ /^\d+$/
        task = component.find_by(name: params[:id]) unless task
        if task
          process_component_logs(task.history)
        else
          TaskVault::Vault._task_not_found
        end
      end

      post '/tasks/add' do
        begin
          component.add(params.keys_to_sym)
        rescue => e
          { status: 500, message: e }
        end
      end

      post '/tasks/cancel/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { status: 404, success: false, request: :cancel, message: 'You must pass a valid task id.' }
        else
          good = component.cancel(params[:id].to_i)
          { status: (good ? 200 : 400), success: good, request: :cancel }
        end
      end

      post '/tasks/rerun/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { status: 404, success: false, request: :rerun, message: 'You must pass a valid task id.' }
        else
          good = component.rerun(params[:id].to_i)
          { status: (good ? 200 : 400), success: component.rerun(params[:id].to_i), request: :rerun }
        end
      end

      delete '/tasks/:id' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :delete_task, message: 'You must pass a valid task id.' }
        else
          good = !component.delete(params[:id].to_i).empty?
          { status: (good ? 200 : 400), success: good, request: :delete_task, id: params[:id] }
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

      [:get, :post, :delete, :put].each do |verb|
        send(verb, '/tasks/:id/*') do
          component.find(params[:id].to_i).call_route(verb, TaskVault::Vault.extract_task_route(request.path_info), params, request)
        end
      end
    end
  end
end
