require 'active_record'
require 'hamlit'
require 'omniauth-twitter'
require 'pry'
require 'pg'
require 'rack-flash'
require 'sinatra'
require 'sinatra/activerecord'
require 'twitter'
require 'yaml'

require_relative 'models/user'
require_relative 'models/yryr_icon'

class MyApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  configure do
    enable :sessions
    use Rack::Flash

    use OmniAuth::Builder do
      provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
    end
  end

  get '/' do
    haml :index
  end

  get '/change' do
    require_authentication!

    @icon = current_user.update_icon_randomly

    haml :complete
  end

  post '/schedule' do
    require_authentication!

    current_user.schedule_at(params[:hours])

    flash[:success] = "毎日 #{params[:hours]} 時に実行されるようにスケジュールしたよ"

    redirect to('/')
  end

  get '/auth/twitter/callback' do
    auth = env['omniauth.auth']
    user = User.find_or_initialize_by(twitter_uid: auth[:uid])
    user.update(token: auth[:credentials][:token], secret: auth[:credentials][:secret])
    session[:current_user_id] = user.id

    redirect to('/')
  end

  helpers do
    def current_user
      User.find_by(id: session[:current_user_id])
    end

    def require_authentication!
      unless current_user
        flash[:error] = 'トップページから Twitter で認証してね'

        redirect to('/')
      end
    end

    def twitter
      Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['CONSUMER_KEY']
        config.consumer_secret     = ENV['CONSUMER_SECRET']
        config.access_token        = current_user.token
        config.access_token_secret = current_user.secret
      end
    end

    def image_urls
      YAML.load_file('./config/image_urls.yml')
    end

    def random_image_path
      image_urls.sample
    end

    def get_yryr_icon(image_path = random_image_path)
      conn = Faraday.new do |faraday|
        faraday.request  :url_encoded
        faraday.response :logger
        faraday.adapter  Faraday.default_adapter
      end

      res = conn.get(image_path)

      tempfile = Tempfile.create(['yryr_img', '.jpg'])
      tempfile.write(res.body)
      tempfile.rewind
      tempfile
    end
  end
end

class Schedule < ActiveRecord::Base
  belongs_to :user

  validates :hours, presence: true, numericality: {greater_than_or_equal_to: 0, less_than: 24}
end
