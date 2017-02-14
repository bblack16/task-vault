module TaskVault
  class Vault < ServerComponent

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
        component.find(params[:id].to_i).serialize
      end

      post '/tasks/add' do
        begin
          component.add(params.keys_to_sym)
        rescue => e
          { error: e }
        end
      end

      post '/tasks/cancel' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :cancel, message: 'You must pass a valid task id.' }
        else
          { success: component.cancel(params[:id].to_i), request: :cancel }
        end
      end

      post '/tasks/rerun' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :rerun, message: 'You must pass a valid task id.' }
        else
          { success: component.rerun(params[:id].to_i), request: :rerun }
        end
      end

      delete '/tasks' do
        if params[:id].nil? || component.find(params[:id].to_i).nil?
          { success: false, request: :delete_task, message: 'You must pass a valid task id.' }
        else
          { success: !component.delete(params[:id].to_i).empty?, request: :delete_task, id: params[:id] }
        end
      end

      get '/queues' do
        component.tasks.map do |q, tasks|
          [q, tasks.map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }]
        end.to_h
      end

      get '/queues/:queue' do
        component.tasks[params[:queue].to_sym].map { |task| { id: task.id, name: task.name, priority: task.priority, weight: task.weight } }
      end
    end
  end
end
