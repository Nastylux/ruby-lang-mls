# frozen_string_literal: true

# Logs subscribe/unsubscribe events to stderr and database.
module MLS
  class Logger

    def initialize(options = {})
      @no_logs = options.fetch(:no_logs, false)
      @db = DB

      warn 'Logging to stdout only'  unless @db
    end

    def log(list, action)
      add_to_log(list, action, "Success")
    end

    def log_invalid(list, action)
      add_to_log(list, action, "Invalid")
    end

    def log_error(list, action, exception)
      add_to_log(list, action, "Error", exception)
    end

    def entries(limit: nil)
      return ["No logs available"]  unless @db

      if limit
        entries = Log.all(:order => [:timestamp.desc], :limit => limit).to_a.reverse
      else
        entries = Log.all(:order => [:timestamp.asc])
      end

      entries.map(&:to_string)
    end

    def recent_entries
      entries(limit: 40)
    end

    def errors(limit: nil)
      return ["No logs available"]  unless @db

      if limit
        entries = Log.all(:status.not => "Success", :order => [:timestamp.desc], :limit => limit).to_a.reverse
      else
        entries = Log.all(:status.not => "Success", :order => [:timestamp.asc])
      end

      entries.map(&:to_string)
    end

    private

    def add_to_log(list, action, status, exception = nil)
      return  if @no_logs

      time = Time.now.utc

      warn time.strftime('[%Y-%m-%d %H:%M:%S %z]') + " #{list}, #{action}, #{status}"
      warn "#{exception.class}: #{exception}"  if exception
      Log.create(
        :timestamp => time,
        :status => status,
        :list => list,
        :action => action,
        :exception => exception ? exception.class.to_s : nil
      )  if @db
    end
  end
end
