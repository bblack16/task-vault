require 'opal'
require 'javascript/vendor/jquery'
require 'opal-jquery'
require 'react/react-source'
require 'reactrb'
require 'browser'
require 'browser/interval'
require 'browser/delay'
require 'javascript/vendor/chart'
require 'javascript/vendor/datatables'
require 'javascript/tables'
require 'javascript/overseer'
require 'dformed'

Document.ready? do
  PARAMS = JSON.parse(Element['#params'].attr('json'))
  Overseer.alert(PARAMS[:alert][:title], PARAMS[:alert][:message], PARAMS[:alert][:severity]) if PARAMS[:alert]
  Tables.load_data_tables
  after(1) { Element['#time'].render(App) }
  if PARAMS[:route] == '/'
    Metrics.get_data
    @timer = every(5) { Metrics.get_data }
  end
  DFC = DFormed::Controller.new
end

class App < React::Component::Base
  before_mount { @timer = every(1) { force_update! } }
  def render
    Time.now.strftime('%H:%M:%S')
  end
end

module Metrics

  def self.cpu
    @cpu
  end

  def self.mem
    @mem
  end

  def self.get_data
    HTTP.get('/metric/cpu') do |response|
      update_cpu response.json[:value].to_i
    end
    HTTP.get('/metric/mem') do |response|
      update_mem response.json[:value].to_i
    end
  end

  def self.setup_cpu value
    @cpu = `new Chart(#{Element["#cpu"]}, #{used_data(value).to_n})`
  end

  def self.setup_mem value
    @mem = `new Chart(#{Element["#mem"]}, #{used_data(value).to_n})`
  end

  def self.update_cpu used
    Element["#cpu_p"].text = "#{used}%"
    if cpu
      `#{cpu}.data.datasets[0].data = [used, 100 - used]`
      `#{cpu}.data.datasets[0].backgroundColor[0] = #{color_for(used)}`
      `#{cpu}.update()`
    else
      setup_cpu(used) unless cpu
    end
  end

  def self.update_mem used
    Element["#mem_p"].text = "#{used}%"
    if mem
      `#{mem}.data.datasets[0].data = [used, 100 - used]`
      `#{mem}.data.datasets[0].backgroundColor[0] = #{color_for(used)}`
      `#{mem}.update()`
    else
      setup_mem(used) unless mem
    end
  end

  def self.color_for used
    {
      10 => "rgb(63, 215, 230)",
      20 => "rgb(63, 180, 230)",
      30 => "rgb(63, 140, 230)",
      40 => "rgb(63, 105, 230)",
      50 => "rgb(176, 63, 230)",
      60 => "rgb(230, 63, 228)",
      70 => "rgb(230, 218, 63)",
      80 => "rgb(230, 193, 63)",
      90 => "rgb(230, 128, 63)",
      100 => "rgb(230, 63, 63)"
    }.find { |v, _| v >= used }[1]
  end

  def self.used_data used
    {
      type: :doughnut,
      data: {
        labels: ['Used', 'Free'],
        datasets: [
          {
            label: 'Percent Used',
            data: [used, 100 - used],
            backgroundColor: [
                color_for(used),
                  "#dbdbdb"
              ],
              hoverBackgroundColor: [
                  color_for(used),
                  "#d5d5d5"
              ]
          }
        ]
      },
      options: {}
    }
  end
end
