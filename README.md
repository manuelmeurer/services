# Services

[![Gem Version](https://badge.fury.io/rb/services.png)](http://badge.fury.io/rb/services)
[![Build Status](https://secure.travis-ci.org/krautcomputing/services.png)](http://travis-ci.org/krautcomputing/services)
[![Dependency Status](https://gemnasium.com/krautcomputing/services.png)](https://gemnasium.com/krautcomputing/services)
[![Code Climate](https://codeclimate.com/github/krautcomputing/services.png)](https://codeclimate.com/github/krautcomputing/services)

Services is a collection of modules and base classes that let you simply add a service layer to your Rails app.

## Motivation

A lot has been written about service layers (service objects, SOA, etc.) for Rails. There are of course advantages and disadvantages, but after using Services since 2013 in several Rails apps, I must say that in my opinion the advantages far outweigh the disadvantages.

**The biggest benefit you get when using a service layer, in my opinion, is that it gets so much easier to reason about your application, find a bug, or implement new features, when all your business logic is in services, not scattered in models, controllers, helpers etc.**

## Usage

For disambiguation: in this README, when you read "Services" with a uppercase "S", this gem is meant, whereas with "services", well, the plural of service is meant.

### Requirements

#### Ruby >= 2.2.3

#### Rails >= 4.0

#### Redis >= 2.8

Redis is used at several points, e.g. to store information about the currently running services, so you can enforce uniqueness for specific services, i.e. make sure no more than one instance of such a service is executed simultaneously.

#### Postgres (optional)

The SQL that `Services::Query` (discussed further down) generates is optimized for Postgres. It might work with other databases but it's not guaranteed. If you're not using Postgres, you can still use all other parts of Services, just don't use `Services::Query` or, even better, submit a [pull request](https://github.com/krautcomputing/services/issues) that fixes it to work with your database!

#### Sidekiq (optional)

To process services in the background, Services uses [Sidekiq](https://github.com/mperham/sidekiq). If you don't need background processing, you can still use Services without Sidekiq. When you then try to enqueue a service for background processing, an exception will be raised. If you use Sidekiq, make sure to load the Services gem after the Sidekiq gem.

### Basic principles

Services is based on a couple of basic principles around what a service should be and do in your app:

A service...

* does only one thing and does it well (Unix philosophy)
* can be run synchronously (i.e. blocking/in the foreground) or asynchronously (i.e. non-blocking/in the background)
* can be configured as "unique", meaning only one instance of it should be run at any time (including or ignoring parameters)
* logs all the things (start time, end time, duration, caller, exceptions etc.)
* has its own exception class(es) which all exceptions that might be raised inherit from
* does not care whether certain parameters are objects or object IDs

Apart from these basic principles, you are free to implement the actual logic in a service any way you want.

### Conventions

Follow these conventions when using Services in your Rails app, and you'll be fine:

* Let your services inherit from `Services::Base`
* Let your query objects inherit from `Services::Query`
* Put your services in `app/services/`
* Decide if you want to use a `Services` namespace or not. Namespacing your service allows you to use a name for them that some other class or module in your app has (e.g. you can have a `Services::Maintenance` service, yet also a `Maintenance` module in `lib`). Not using a namespace saves you from writing `Services::` everytime you want to reference a service in your app. Both approaches are fine, pick one and stick to it.
* Give your services "verby" names, e.g. `app/services/users/delete.rb` defines `Users::Delete` (or `Services::Users::Delete`, see above). If a service operates on multiple models or no models at all, don't namespace them (`Services::DoStuff`) or namespace them by logical groups unrelated to models (`Services::Maintenance::CleanOldStuff`, `Services::Maintenance::SendDailySummary`, etc.)
* Some services call other services. Try to not combine multiple calls to other services and business logic in one service. Instead, some services should contain only business logic and other services only a bunch of service calls but no (or little) business logic. This keeps your services nice and modular.

### Configuration

You can/should configure Services in an initializer:

```ruby
# config/initializers/services.rb
Services.configure do |config|
  config.logger = Services::Logger::Redis.new(Redis.new)    # see [Logging](#Logging)
  config.redis  = Redis.new                                 # optional, if `Redis.current` is defined. Otherwise it is recommended to use
                                                            # a [connection pool](https://github.com/mperham/connection_pool) here instead of simply `Redis.new`.
end
```

### Rails autoload fix for `Services` namespace

By default, Rails expects `app/services/users/delete.rb` to define `Users::Delete`. If you want to use the `Services` namespace for your services, we want it to expect `Services::Users::Delete`. To make this work, add the `app` folder to the autoload path:

```ruby
# config/application.rb
config.autoload_paths += [config.root.join('app')]
```

This looks as if it might break things, but AFAIK it has never cause problems so far.

### Services::Base

`Services::Base` is the base class you should use for all your services. It gives you a couply of helper methods and defines a custom exception class for you.

Read [the source](lib/services/base.rb) to understand what it does in more detail.

The following example service takes one or more users or user IDs as an argument and deletes the users:

```ruby
module Services
  module Users
    class Delete < Services::Base
      def call(ids_or_objects)
        users = find_objects(ids_or_objects)
        users.each do |user|
          if user.posts.any?
            raise Error, "User #{user.id} has one or more posts, refusing to delete."
          end
          user.destroy
          Mailer.user_deleted(user).deliver
        end
        users
      end
    end
  end
end
```

This service can be called in several ways:

```ruby
# Execute synchronously/in the foreground

Services::Users::Delete.call User.find(1)                # with a user object
Services::Users::Delete.call User.where(id: [1, 2, 3])   # with a ActiveRecord::Relation returning user objects
Services::Users::Delete.call [user1, user2, user3]       # with an array of user objects
Services::Users::Delete.call 1                           # with a user ID
Services::Users::Delete.call [1, 2, 3]                   # with an array of user IDs

# Execute asynchronously/in the background

Services::Users::Delete.perform_async 1                  # with a user ID
Services::Users::Delete.perform_async [1, 2, 3]          # with multiple user IDs
```

As you can see, you cannot use objects or a ActiveRecord::Relation as parameters when calling a service asynchronously since the arguments are serialized to Redis. This might change once Services works with [ActiveJob](https://github.com/rails/rails/tree/master/activejob) and [GlobalID](https://github.com/rails/globalid/).

The helper `find_objects` is used to allow the `ids_or_objects` parameter to be a object, object ID, array or ActiveRecord::Relation, and make sure you we dealing with an array of objects from that point on.

It's good practice to always return the objects a service has been operating on at the end of the service.

### Services::Query

`Services::Query` on the other hand should be the base class for all query objects.

Here is an example that is used to find users:

```ruby
module Services
  module Users
    class Find < Services::Query
      convert_condition_objects_to_ids :post

      private def process(scope, conditions)
        conditions.each do |k, v|
          case k
          when :email, :name
            scope = scope.where(k => v)
          when :post_id
            scope = scope.joins(:posts).where("#{Post.table_name}.id" => v)
          else
            raise ArgumentError, "Unexpected condition: #{k}"
          end
        end
        scope
      end
    end
  end
end
```

A query object that inherits from `Services::Query` always receives two parameters: an array of IDs and a hash of conditions. It always returns an array, even if none or only one object is found.

When you write your query objects, the only method you have to write is `process` (preferably make it private). This method does the actual querying for all non-standard parameters (more about standard vs. non-standard parameters below).

This is how `Services::Users::Find` can be called:

```ruby
Services::Users::Find.call []                             # find all users, neither filtered by IDs nor by conditions
Services::Users::Find.call [1, 2, 3]                      # find users with ID 1, 2 or 3
Services::Users::Find.call 1                              # find users with ID 1 (careful: returns an array containing this one user, if found, otherwise an empty array)
Services::Users::Find.call [], email: 'foo@bar.com'       # find users with this email address
Services::Users::Find.call [1, 2], post: Post.find(1)     # find users with ID 1 or 2 and having the post with ID 1
Services::Users::Find.call [1, 2], post: [Post.find(1)]   # same as above
Services::Users::Find.call [1, 2], post: 1                # same as above
```

Check out [the source of `Services::Query`](lib/services/query.rb) to understand what it does in more detail.

#### Standard vs. non-standard parameters

to be described...

#### convert_condition_objects_to_ids

As with service objects, you want to be able to pass objects or IDs as conditions to query objects as well, and be sure that they behave the same way. This is what `convert_condition_objects_to_ids :post` does in the previous example: it tells the service object to convert the `post` condition, if present, to `post_id`.

For example, at some point in your app you have an array of posts and need to find the users that created these posts. `Services::Users::Find.call([], post: posts)` will find them for you. If you have a post ID on the other hand, simply use `Services::Users::Find.call([], post: post_id)`, or if you have a single post, use `Services::Users::Find.call([], post: post)`. Each of these calls will return an array of users, as you would expect.

`Services::Query` takes an array of IDs and a hash of conditions as parameters. It then extracts some special conditions (:order, :limit, :page, :per_page) that are handled separately and passes a `ActiveRecord::Relation` and the remaining conditions to the `process` method that the inheriting class must define. This method should handle all the conditions, extend the scope and return it.

### Helpers

Your services inherit from `Services::Base` which makes several helper methods available to them:

* `Rails.application.routes.url_helpers` is included so you use all Rails URL helpers.
* `find_objects` and `find_object` let you automatically find object or a single object from an array of objects or object IDs, or a single object or object ID. The only difference is that `find_object` returns a single object whereas `find_objects` always returns an array.
* `object_class` tries to figure out the class the service operates on. If you follow the service naming conventions and you have a service `Services::Products::Find`, `object_class` will return `Product`. Don't call it if you have a service like `Services::DoStuff` or it will raise an exception.

Your services also automatically get a custom `Error` class, so you can `raise Error, 'Uh-oh, something has gone wrong!'` in `Services::MyService` and a `Services::MyService::Error` will be raised.

### Logging

You can choose between logging to Redis or to a file, or turn logging off. By default logging is turned off.

#### Redis

to be described...

#### File

to be described...

### Exception wrapping

to be described...

### Uniqueness checking

to be described...

### Background/asynchronous processing

Each service can run synchronously (i.e. blocking/in the foreground) or asynchronously (i.e. non-blocking/in the background). If you want to run a service in the background, make sure it takes only arguments that can be serialized without problems (i.e. integers, strings, etc.). The background processing is done by Sidekiq, so you must set up Sidekiq in the Services initializer.

## Installation

Add this line to your application's Gemfile:

    gem 'services'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install services

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Testing

You need Redis to run tests, check out the [Guardfile](Guardfile) which loads it automatically when you start Guard!
