# JSON API

json-api is a simple library similar to rest-client and httparty, which helps with wrappers around APIs.

## Installing

```
gem install json_api

require 'json-api'
```

## Quick requests

If you want to do only a couple of requests, then you could call methods directly on JsonApi.<br>
`get`, `post`, `delete` and `put` methods are available. Parameters are passed as a hash.<br>
`code`, `body`, `json`, `hash`, `message` are the most noticeable attributes of responses.


```ruby
res = JsonApi.get 'https://api.github.com/search/repositories', q: 'created:>2015-04-01 stars:>100'

puts res.code #=> '200'
puts res.body #=> "{\"total_count\":82,\"incomplete_results\":false,\"items\":[{\"id\":33538019..."
puts res.json #=> pretty json
puts res.hash #=> ruby hash object from parsed json
```

## Writing a wrapper

When you work with an API probably you would like to specify `base_path` for all requests.<br>
Also you may want to specify some `default_params`.<br>
Now lets create a wrapper with a parametrized method.

```ruby
class GitHubApi
  include JsonApi

  def initialize
    @base_path      = 'https://api.github.com'
    @default_params = { per_page: 12 }
  end

  def search(created, stars)
    res = get 'search/repositories', q: "created:>#{created} stars:>#{stars}"

    raise res.hash['message'] unless res.ok?
    res.hash['items']
  end
end

repos = GitHubApi.search('2015-04-01', 100) #=> array with 12 repositories
```

We've included JsonApi module.<br>
As you can see we can specify `@base_path` and `@default_params` in initialization.<br>
It will work for all requests.<br>
Methods like `get` method are available now in the class,<br>
and we've used `get` in `search` method body.<br>
See "Quick requests" for details about http methods and response methods.

## Parametrized initialization

Note we've used `GitHubApi.search` instead of `GitHubApi.new.search` variant.<br>
Library allows you to do that.<br>
But usually you need to configure an instance of wrapper.<br>

```ruby
class GitHubApi
  include JsonApi

  def initialize(per_page)
    @base_path      = 'https://api.github.com'
    @default_params = { per_page: per_page }
  end

  # ...
end

github_api = GitHubApi.new(12)

repos = github_api.search('2015-04-01', 100) #=> array with 12 repositories
```

## Error handling

Usually an API have a consistent way of returning errors.<br>
And usually you want to handle them consistently.<br>

Suppose we need to handle errors as following:

```ruby
raise 'GitHubApi: Error message: ' + res.hash['message'] unless res.ok?
```

It would be too bad to write such code everywhere.<br>
So write just `raise res.error unless res.ok?`, and add next method:

```ruby
def error(res)
  'GitHubApi: Error message: ' + res.hash['message']
end
```

`error` method will be generated automatically for responses.<br>
`ok?` method which was used already several times returns true if code is "200".

## Logging

You may specify logger for debugging. It should be a Proc object.<br>
For example `proc { |s| puts s }` or just `method(:puts)`.<br>

```ruby
class GitHubApi
  include JsonApi

  def initialize
    @base_path      = 'https://api.github.com'
    @default_params = { per_page: 12 }
    @logger         = method(:puts)
  end

  # ...
end

repos = GitHubApi.search('2015-04-01', 100)
```

Example with using ActiveSupport:

```ruby
# standalone application
@logger = ActiveSupport::Logger.new(STDOUT).method(:info)
# in rails
@logger = logger.method(:info)
```

It will produce output:

```
[JsonApi#request begin]
# Request
Method - get
Path   - https://api.github.com/search/repositories
Params -
{:per_page=>12, :q=>"created:>2015-04-01 stars:>100"}
# Response
Code - 200
Body -
{
  "total_count": 82,
  "incomplete_results": false,
  "items": [
    {
      "id": 33538019,
      ...
[JsonApi#request end]
```

## Configuring requests

If you want to provide headers, or prepare request in other way,<br>
You may override method called `configure_request`.

```ruby
def configure_request(req)
  req['Authorization'] = session[:token]
end
```

## Routing

It's nice to have all routes in one single place.<br>
The library provides `routes` class method, which accepts a hash.<br>
For every named route `#{name}_path` method will be generated automatically.<br>
Take a look at the code.

```ruby
class GitHubApi
  include JsonApi

  def initialize
    @base_path      = 'https://api.github.com'
    @default_params = { per_page: 12 }
  end

  routes search: 'search/repositories',
           user: -> name { "users/#{name}" }

  def search(created, stars)
    res = get search_path, q: "created:>#{created} stars:>#{stars}"

    raise res.error unless res.ok?
    res.hash['items']
  end

  def user(name)
    res = get user_path(name)

    raise res.error unless res.ok?
    res.hash
  end

  def error(res)
    res.hash['message']
  end
end

repos = GitHubApi.search('2015-04-01', 100)
user = GitHubApi.user('dhh')
```

**Author (Speransky Danil):**
[LinkedIn](http://ru.linkedin.com/in/speranskydanil/en) |
[GitHub](https://github.com/speranskydanil?tab=repositories) |
[StackOverflow](http://stackoverflow.com/users/1550807/speransky-danil)

