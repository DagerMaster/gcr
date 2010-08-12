#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'patron'
require 'json'
require 'erb'
require 'gh-api'

### DB ###

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/my.db")

class User
  include DataMapper::Resource

  property :username, String, :key => true, :unique => true
  property :token, String
  property :email, String

  has n, :collaborators
  has n, :repos, :through => :collaborators

  has n, :reviews

end

class Repo
  include DataMapper::Resource

  # URL only stores username/repo_name, not http://github.com/
  property :url, String, :key => true, :unique => true

  has n, :commits

  has n, :collaborators
  has n, :users, :through => :collaborators
end

class Collaborator
  include DataMapper::Resource

  belongs_to :repo, :key => true
  belongs_to :user, :key => true

  property :reviewer, Boolean

end

class Commit
  include DataMapper::Resource

  property :id,          Serial
  property :commit_hash, String
  property :message,     String
  property :author_name, String
  property :author_email,String
  property :timestamp,   DateTime
  property :url,         String

  belongs_to :repo

  has n, :reviews
end

class Review
  include DataMapper::Resource

  belongs_to :commit, :key => true
  belongs_to :user, :key => true

  property :url, String
  property :completed, Boolean
  property :approved, Boolean
  property :date, DateTime

  has n, :comments

end

class Comment
  include DataMapper::Resource

  property :id, Serial
  property :body, String

  belongs_to :review

end

DataMapper.finalize

DataMapper.auto_upgrade!

### End DB ###

enable :sessions

get '/' do
  if session[:username]
    redirect "/reviews/"
  end
  if session[:loginerror]
    @msg = session[:loginerror]
  else
    @msg = "please enter your github credentials below"
  end
  erb :index
end

post '/login/?' do
  session[:loginerror] = nil
  user = User.get(params[:username])
  if user
    if user[:token] == params[:token]
      session[:username] = user[:username]
      session[:token] = user[:token]
      redirect "/reviews/"
    else
      # User may have been added as a collaborator first
      hub = Hubber.new(params[:username], params[:token])
      if hub.authenticate
        user[:token] = params[:token]
        user.save
        redirect "/reviews/"
      else
        session[:loginerror] = "improper credentials provided. please try again"
        redirect "/"
      end
    end
  else
    hub = Hubber.new(params[:username], params[:token])
    if hub.authenticate
      user = User.new(:username => params[:username],
                      :token => params[:token])
      if user.save
        session[:username] = user[:username]
        session[:token] = user[:token]
        redirect "/reviews/"
      else
        session[:loginerror] = "an error occured. please try again"
        redirect "/"
      end
    else
        session[:loginerror] = "improper credentials provided. please try again"
        redirect "/"
    end
  end
end

get '/logout/?' do
  session[:loginerror] = nil
  session[:username] = nil
  session[:token] = nil
  redirect '/'
end

post '/post/?' do
  push = JSON params[:payload]
  repo = Repo.get(push["repository"]["url"].split("http://github.com/")[1])
  if repo
    collaborators = Collaborator.all(:repo => repo)
    start = push["before"]
    push["commits"].each do |commit|
      c = Commit.new(:commit_hash => commit["id"],
                     :message => commit["message"],
                     :author_name => commit["author"]["name"],
                     :author_email => commit["author"]["email"],
                     :timestamp => nil,
                     :url => commit["url"])
      c.save
      reviewers = collaborators.sort_by{ rand }.slice(0...5)
      reviewers.each do |r|
        rev = Review.new(:commit => c,
                         :url => repo.url + "compare/" + start + "..." + commit["id"],
                         :user => r)
        rev.save
      end
      start = commit["id"]
    end
  end
end
  
get '/reviews/?' do
  if not session[:username]
    redirect "/"
  end
  @user = User.get(session[:username])
  hub = Hubber.new(session[:username], session[:token])
  @repos_on = []
  @repos_off = []
  hub.repo_list.each do |url|
    repo = Repo.get(url)
    if not repo
      @repos_off.push(url)
    else
      @repos_on.push(url)
    end
  end
  reviews = Review.all(:user => @user)
  @revs_pending = []
  @revs_completed = []
  reviews.each do |rev|
    if rev.completed
      @revs_completed.push(rev)
    else
      @revs_pending.push(rev)
    end
  end
  erb :reviews, :layout => false
end

post '/add-email/?' do
  user = User.get(session[:username])
  if user
    user.email = params[:email]
    user.save
  end
end

post '/start-review/?' do
  repo = Repo.new(:url => params[:repo])
  hub = Hubber.new(session[:username], session[:token])
  collaborators = hub.repo_detail(params[:repo])
  collaborators.each do |c|
    user = User.get(c)
    if not user
      user = User.new(:username => c)
      user.save
    end
    cc = Collaborator.new(:repo => repo,
                          :user => user)
    if c != "meteorsolutions"
      # TODO: HACK
      cc[:reviewer] = true
    else
      cc[:reviewer] = false
    end
    cc.save
  end
end

get '/reviews/:review/?' do
  erb :index
end

# Not sure if we want this one
#get '/reviews/:review/review/?' do
#  erb :index
#end

post '/reviews/:review/comment/?' do
  erb :index
end

post '/reviews/:review/accept/?' do
  erb :index
end

post '/reviews/:review/reject/?' do
  erb :index
end
