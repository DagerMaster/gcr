#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'json'
require 'erb'
require 'github'

### DB ###

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/gcr.db")

class User
  include DataMapper::Resource

  property :username, String, :key => true, :unique => true
  property :token, String
  property :email, String
  property :is_reviewer, Boolean

  has n, :collaborations
  has n, :repos, :through => :collaborations

  has n, :reviews

end

class Repo
  include DataMapper::Resource

  # URL only stores username/repo_name, not http://github.com/
  property :url, String, :key => true, :unique => true, :length => 1..255

  has n, :collaborations
  has n, :users, :through => :collaborations

end

class Collaboration
  include DataMapper::Resource

  belongs_to :repo, :key => true
  belongs_to :user, :key => true

  property :reviewer, Boolean

end

class Push
  include DataMapper::Resource

  property :id, Serial
  property :before, String, :unique => true
  property :after, String, :unique => true

  belongs_to :repo
  belongs_to :user
end

class Review
  include DataMapper::Resource

  property :id, Serial
  property :url, String, :length => 1..255
  property :completed, Boolean, :default => false
  property :approved, Boolean, :default => false
  property :date, DateTime, :default => DateTime.now

  belongs_to :push
  belongs_to :user

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
  erb :login
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
      # User may have been added as a collaborator first, check if we need to add
      hub = GitHub.new(params[:username], params[:token])
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
    hub = GitHub.new(params[:username], params[:token])
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
  payload = JSON.parse(params[:payload])
  repo = Repo.get(payload["repository"]["url"].split(/https?:\/\/github\.com\//)[1])
  pusher = User.get(payload["pusher"]["name"])
  if not pusher
    pusher = User.create(:username => payload["pusher"]["name"])
  end
  push = Push.create(:repo => repo,
                     :before => payload["before"],
                     :after => payload["after"],
                     :user => pusher)
  if repo && push.saved? && pusher.saved?
    reviewers = Collaboration.all(:repo => repo,
                                  :reviewer => true,
                                  :user.not => pusher)
    reviewers.sort_by{ rand }.slice(0...2).each do |r|
      rev = Review.create(:push => push,
                          :user => r.user,
                          :url => payload["compare"])
    end
  end
  nil
end

get '/reviews/?' do
  if not session[:username]
    redirect "/"
  end
  @user = User.get(session[:username])
  hub = GitHub.new(session[:username], session[:token])
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
  erb :dashboard
end

post '/add-email/?' do
  user = User.get(session[:username])
  if user
    user.email = params[:email]
    user.save
  end
  nil
end

post '/reviewer-status/' do
  user = User.get(session[:username])
  if user
    user.is_reviewer = params[:accepted]
    user.save
  end
  nil
end

post '/start-review/?' do
  if params[:repo].split("/")[0] == session[:username]
    repo = Repo.new(:url => params[:repo])
    hub = GitHub.new(session[:username], session[:token])    
    collaborators = hub.repo_collaborators(params[:repo])
    collaborators.each do |c|
      user = User.get(c)
      if not user
        user = User.create(:username => c)
      end
      cc = Collaboration.new(:repo => repo,
                             :user => user)
      # Don't add as reviewer if they've requested not to.
      if user.username == repo.url.split("/")[0] && (!user.is_reviewer)
        cc[:reviewer] = false
      else
        cc[:reviewer] = true
      end
      cc.save
    end
  end
  nil
end

get '/reviews/:review/?' do
  @rev = Review.get(params[:review])
  if @rev.user.username == session[:username]
    erb :review
  else
    redirect "/reviews/"
  end
end

post '/reviews/:review/comment/?' do
  if session[:username]
    rev = Review.get(params[:review])
    if rev.user.username == session[:username]
      comment = Comment.create(:body => params[:comment],
                               :review => rev)
    end
  end
  nil
end

get '/reviews/:review/accept/?' do
  rev = Review.get(params[:review])
  if rev.user.username == session[:username]
    if not rev.completed
      rev.approved = true
      rev.completed = true
      rev.save
    end
  end
  redirect "/reviews/"
end

get '/reviews/:review/reject/?' do
  rev = Review.get(params[:review])
  if rev.user.username == session[:username]
    if not rev.completed  
      rev.approved = false
      rev.completed = true
      rev.save
    end
  end
  redirect("/reviews/")
end
