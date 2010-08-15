require 'rubygems'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'

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
  property :date, Date

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

