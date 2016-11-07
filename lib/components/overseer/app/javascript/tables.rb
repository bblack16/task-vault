
module Tables
  def self.load_data_tables
    Element['.data_table'].each do |table|
      opts = { buttons: [:copy, :excel, :colvis, :print] }
      if table.attr('dt_ajax')
        opts[:ajax] = table.attr('dt_ajax')
      end
      `console.log(#{opts.to_n})`
      data_table = table.JS.dataTable(opts.to_n)
      every(10, data_table.JS.reload) if opts[:ajax]
    end
  end
end
