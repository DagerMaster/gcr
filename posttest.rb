require 'rubygems'
require 'json'

a = '
{
  "after": "274a895321ce36704e572e288a3e8f651ed6462d", 
  "before": "66d4957b8785a1f7b9239313158a7f111610606f", 
  "commits": [
    {
      "added": [
        "ASDF"
      ], 
      "author": {
        "email": "b@banjiewen.net", 
        "name": "Benjamin Anderson"
      }, 
      "id": "274a895321ce36704e572e288a3e8f651ed6462d", 
      "message": "asdf", 
      "modified": [], 
      "removed": [], 
      "timestamp": "2010-08-11T20:30:49-07:00", 
      "url": "http:\/\/github.com\/banjiewen\/gcrtest\/commit\/274a895321ce36704e572e288a3e8f651ed6462d"
    }
  ], 
  "compare": "http:\/\/github.com\/banjiewen\/gcrtest\/compare\/66d4957...274a895", 
  "forced": false, 
  "pusher": {
    "email": "b@banjiewen.net", 
    "name": "banjiewen"
  }, 
  "ref": "refs\/heads\/master", 
  "repository": {
    "created_at": "2010\/08\/11 20:24:06 -0700", 
    "description": "", 
    "fork": false, 
    "forks": 0, 
    "has_downloads": true, 
    "has_issues": true, 
    "has_wiki": true, 
    "homepage": "", 
    "name": "gcrtest", 
    "open_issues": 0, 
    "owner": {
      "email": "b@banjiewen.net", 
      "name": "banjiewen"
    }, 
    "private": false, 
    "pushed_at": "2010\/08\/11 20:30:55 -0700", 
    "url": "http:\/\/github.com\/banjiewen\/gcrtest", 
    "watchers": 1
  }
}
'

push= JSON a
puts push["repository"]["url"]
push["commits"].each do |commit|
  puts commit["id"]
end
