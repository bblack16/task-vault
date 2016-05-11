

class TaskVault

  class TaskVaultLogger < TaskVaultHandler
    attr_reader :path

    def path= pth
      @path = pth.to_s
    end

    def process_message
      begin
        data = read_msg
        if (data[:severity] || 0).to_i <= @level
          "\n#{construct_msg(data).join(' - ').strip}".to_file(construct_path)
        end
      rescue Exception => e
        puts e
      end
    end

    protected
      def setup_defaults
        super
        @path = 'task_vault_YYYYMMDD.log'
      end

      def construct_path
        @path.dup.gsub('YYYY', Time.now.year.to_s).gsub('MM', Time.now.month.to_s.rjust(2,'0')).gsub('DD',Time.now.day.to_s.rjust(2,'0')).gsub('HH', Time.now.hour.to_s.rjust(2, '0')).gsub('MIN', Time.now.min.to_s.rjust(2, '0'))
      end

      def setup_serialize_fields
         [:time_format, :level, :path]
      end

  end

end
