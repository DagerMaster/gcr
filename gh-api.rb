require 'rubygems'
require 'patron'
require 'json'

class Hubber
  def initialize(username, token)
    @username = username
    @token = token
    @sess = Patron::Session.new
    @sess.base_url = "http://github.com/api/v2/json"
    @sess.username = username + "/token"
    @sess.password = token
    @sess.auth_type = :basic
  end

  def authenticate
    response = @sess.get "/user/show/" + @username
    body = JSON response.body
    if body["user"]["plan"]
      true
    else
      false
    end
  end

  def repo_list
    response = @sess.get "/repos/show/" + @username
    body = JSON response.body
    repos = []
    body["repositories"].each do |repo|
      repos.push repo["url"].split(/https?:\/\/github\.com\//)[1]
    end
    repos
  end

  def repo_detail(repo_path)
    response = @sess.get "/repos/show/" + repo_path + "/collaborators"
    body = JSON response.body
    body["collaborators"]
  end
end
    
