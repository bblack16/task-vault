class ComponentsTable < React::Component::Base
  before_mount do
    refresh_content
    @timer = every(1) do
      refresh_content
    end
  end

  def content= p
    @content = p
  end

  def content
    @content ||= {}
  end

  def refresh_content
    HTTP.get('/api/components') do |response|
      self.content = response.json
      force_update!
    end
  end

  def render
    # div(dangerously_set_inner_HTML: { __html: content })
    table.default do
      thead do
        tr do
          th
          th { 'Name' }
          th { 'Status' }
          th { 'Uptime' }
          th
        end
      end
      tbody do
        content.each do |component|
          tr do
            td do
              img(style: { width: '35px', height: '35px' }, src: "/assets/images/components/#{component[:class]}.svg".gsub('TaskVault::', '').downcase)
            end
            td { component[:name] }
            td do
              div(class: "btn btn-#{component[:running] ? 'success' : 'danger'}") { component[:running] ? 'Up' : 'Down' }
            end
            td { component[:uptime].to_nearest_duration }
            td do
              if component[:running]
                div.btn.btn_group do
                  button(class: 'btn btn-warning') { 'Stop' }.on(:click) { Overseer.component_cmd(component[:name], :stop); force_update! }
                  button(class: 'btn btn-info') { 'Restart' }.on(:click) { Overseer.component_cmd(component[:name], :restart); force_update! }
                end
              else
                button(class: 'btn btn-default') { 'Start' }.on(:click) { Overseer.component_cmd(component[:name], :start); force_update! }
              end
            end
          end
        end
      end
    end
  end
end
