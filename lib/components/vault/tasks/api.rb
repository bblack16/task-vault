module TaskVault
  class Task < SubComponent

    views_path File.expand_path('../app/views', __FILE__)

    get '/' do
      view_render(:slim, :index, Task)
    end

    def describe
      super.merge(
        status:           status,
        stats:            stats,
        run_count:        run_count,
        initial_priority: initial_priority,
        running:          running?,
        times:            times
      )
    end

    protected

    # def setup_routes
      # super

      # get_api '/' do
      #   { message: "I'm a task!" }
      # end
      #
      # get '/stats' do
      #   { timers: stats, timestamps: times, run_count: run_count }
      # end
      #
      # [:cancel, :rerun, :elevate].each do |action|
      #   put "/#{action}" do
      #     { action => send(action) }
      #   end
      # end
      #
      # delete '/' do
      #   { delete: parent.remove(id) }
      # end

    # end
  end
end
