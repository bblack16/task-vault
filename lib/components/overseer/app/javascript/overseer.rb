

module Overseer
  SEVERITIES = {
    success: 'rgb(77, 210, 78)',
    warning: 'rgb(255, 146, 0)',
    error:   'rgb(228, 51, 51)',
    info:    'rgb(0, 202, 255)',
    nil:     'rgb(184, 184, 184)'
  }

  def self.alert title, message, severity = :success
    alert = Element['#o_alert']
    closer = Element["<span id='alert_close' class='glyphicon glyphicon-remove close_alert'></span>"]
    alert.html = "<b>#{title}:</b> #{message}"
    alert.css('background-color', SEVERITIES[severity])
    alert.append(closer)
    closer.on(:click) { |_evt| hide_alert }
    alert.show
  end

  def self.hide_alert
    Element['#o_alert'].hide
  end

end
