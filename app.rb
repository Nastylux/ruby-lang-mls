# ruby-lang.org mailing list service/subscriber
#
# project home page: https://github.com/stomar/ruby-lang-mls
#
# Copyright (C) 2013 Marcus Stollsteimer
#
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

require 'sinatra/base'
require 'pony'
require 'uri'
require 'pg'

USERNAME     = ENV['SMTP_USERNAME']
PASSWORD     = ENV['SMTP_PASSWORD']
SMTP_ADDRESS = ENV['SMTP_SERVER']
SMTP_PORT    = ENV['SMTP_PORT'] || '587'
NO_CONFIRM   = ENV['NO_CONFIRM'] == 'true'
NO_LOGS      = ENV['NO_LOGS'] == 'true'
DATABASE_URL = ENV['DATABASE_URL']


Pony.options = {
  :subject => '',
  :sender => USERNAME,
  :via => :smtp,
  :via_options => {
    :user_name      => USERNAME,
    :password       => PASSWORD,
    :address        => SMTP_ADDRESS,
    :port           => SMTP_PORT,
    :authentication => :plain,
    :enable_starttls_auto => true,
  }
}


# Logs subscribe/unsubscribe events to stderr and database.
#
# Test locally with URL 'postgres://localhost/dbname'.
class MLLogger

  def initialize(database_url = nil)
    @database_url = database_url
    @db = nil

    if @database_url
      db = URI.parse(@database_url)

      options = {
        :host => db.host,
        :user => db.user,
        :password => db.password,
        :dbname => db.path[1..-1]
      }.delete_if {|k, v| v.nil? || [k, v] == [:host, 'localhost'] }

      begin
        @db = PG::Connection.open(options)
        @db.prepare('insert', 'INSERT INTO logs (entry) VALUES ($1)')
        @db.prepare('recent', 'SELECT entry FROM logs ORDER BY entry DESC LIMIT 40')
      rescue PG::Error => e
        warn "Error initializing database: #{e}"
        warn 'Logging to stdout only'
        @db = nil
      end
    end
  end

  def log(time, status, list, action, exception = nil)
    return  if NO_LOGS

    entry =  "#{time.strftime('[%Y-%m-%d %H:%M:%S %z]')}"
    entry << " STAT  " << status.ljust(7)
    entry << " (" << (list + ',').ljust(10) << " #{action})"
    entry << " #{exception.class}"  if exception

    warn entry
    warn "#{exception.class}: #{exception}"  if exception
    @db.exec_prepared('insert', [entry])  if @db
  end

  def recent_entries
    return "No logs available\n"  unless @db

    rows = @db.exec_prepared('recent', [])
    entries = rows.map {|row| row['entry'] }

    entries.sort.join("\n") << "\n"
  end
end


class MLRequest

  attr_reader :list, :first_name, :last_name, :email, :action

  ACTIONS = ['subscribe', 'unsubscribe']
  LISTS   = ['ruby-talk', 'ruby-core', 'ruby-doc', 'ruby-cvs']

  def initialize(params)
    @list = params[:list] || ''
    @first_name = params[:first_name] || ''
    @last_name = params[:last_name] || ''
    @email = params[:email] || ''
    @action = params[:action] || ''
  end

  def valid?
    @first_name =~ /\A[a-zA-Z]+\Z/ &&
    @last_name  =~ /\A[a-zA-Z]+\Z/ &&
    !@email.empty? &&
    LISTS.include?(@list) && ACTIONS.include?(@action)
  end

  def mail_options
    {
      :to   => "#{@list}-ctl@ruby-lang.org",
      :from => @email,
      :body => "#{@action} #{@first_name} #{@last_name}"
    }
  end
end


class App < Sinatra::Base

  set :environment, :production

  configure do
    set :mllogger, MLLogger.new(DATABASE_URL)
  end

  helpers do
    def escape(text)
      Rack::Utils.escape_html(text)
    end
  end

  get '/' do
    erb :index
  end

  post '/submit' do
    @ml_request = MLRequest.new(params)
    time        = Time.now

    if @ml_request.valid?
      begin
        Pony.mail(@ml_request.mail_options)
        @status  =  'Confirmation'
        @message =  'Your request has been accepted. '
        @message << 'You should receive a confirmation email shortly.'
        settings.mllogger.log(time, 'Success', @ml_request.list, @ml_request.action)
      rescue => e
        @status  = 'Error'
        @message = 'Sorry, an error occurred during processing of your request.'
        settings.mllogger.log(time, 'Error', @ml_request.list, @ml_request.action, e)
      end
    else
      @status  =  'Invalid request'
      @message =  'Your request is invalid. '
      @message << 'Please make sure that you filled out all fields.'
      settings.mllogger.log(time, 'Invalid', @ml_request.list, @ml_request.action)
    end

    if NO_CONFIRM
      redirect back
    else
      erb :confirmation
    end
  end

  get '/logs/?' do
    content_type :txt
    settings.mllogger.recent_entries
  end
end
