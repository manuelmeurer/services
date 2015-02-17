# Services

[![Gem Version](https://badge.fury.io/rb/services.png)](http://badge.fury.io/rb/services)
[![Build Status](https://secure.travis-ci.org/krautcomputing/services.png)](http://travis-ci.org/krautcomputing/services)
[![Dependency Status](https://gemnasium.com/krautcomputing/services.png)](https://gemnasium.com/krautcomputing/services)
[![Code Climate](https://codeclimate.com/github/krautcomputing/services.png)](https://codeclimate.com/github/krautcomputing/services)

Services is a small collection of modules and base classes that let you implement a nifty service layer in your Rails app.

## Motivation

A lot has been written about service layers in Rails apps. There are of course advantages and disadvantages, but after using Services since 2013 in several Rails apps, I must say that in my opinion the advantages far outweigh the disadvantages.

**The biggest benefit you get when using a service layer is that it gets much easier to reason about your application, find a bug, or implement new features, when all your business logic is in services, not scattered in models, controllers, helpers etc.**

## Usage

For disambiguation: when I write "Services" with a uppercase "S", I mean this gem, whereas with "services" I mean, well, the plural of service.

### Requirements

### Ruby

Ruby >= 2.0

#### Rails

Rails >= 3.2

#### Redis

Redis is used at several points, e.g. to store information about the currently running services, so you can make sure a certain service is not executed more than once simultaneously.

#### Postgres

The SQL that `Services::Query` (discussed further down) generates is optimized for Postgres. It might work with other databases but it's not guaranteed. If you're not using Postgres, don't use `Services::Query` or, even better, submit a [pull request](https://github.com/krautcomputing/services/issues) that fixes it to work with your database!

#### Sidekiq (optional)

To process services in the background, Services uses [Sidekiq](https://github.com/mperham/sidekiq). Sidekiq is not absolutely required to use Services though. If it's not present when Services is loaded, a service will raise an exception when you try to enqueue it for background processing. If you use Sidekiq, make sure to load the Services gem after the Sidekiq gem.

### Basic principles

Services is based on a couple of basic principles around what a service should be and do in your app:

A service...

* does one thing and does it well (Unix philosophy)
* can be run synchronously (in the foreground) or asynchronously (in the background)
* can be configured as "unique", meaning only one instance of it should be run at any time
* logs all the things (start time, end time, duration, caller, exceptions etc.)
* has its own exception class(es) that all exceptions that it may raise inherit from
* can be called with objects or IDs as parameters

Apart from these basic principles, you can implement the actual logic in a service any way you want.

### Conventions

Follow these conventions when using Services in your Rails app:

* Let your services inherit from `Services::Base` (or `Services::Query`)
* Put your services in `app/services/`
* Namespace your services with the model they operate on and give them verb names, e.g. `app/services/users/delete.rb` defines `Services::Users::Delete`. If a service operates on multiple models or no models at all, don't namespace them (`Services::DoStuff`) or namespace them by logical groups unrelated to models (`Services::Maintenance::CleanOldStuff`, `Services::Maintenance::SendDailySummary`, etc.)
* Some services call other services. Try to not combine multiple calls to other services and business logic in one service. Instead, some services should contain only business logic and other services only a bunch of service calls but no (or little) business logic. This keeps your services nice and modular.

### Configuration

You can/should configure Services in an initializer:

```ruby
# config/initializers/services.rb
Services.configure do |config|
  config.logger = Services::Logger::Redis.new(Redis.new) # or Services::Logger::File.new(Rails.root.join('log'))
  config.redis  = Redis.new
end
```

### Rails autoload fix

By default, Rails expects `app/services/users/delete.rb` to define `Users::Delete`, but we want it to expect `Services::Users::Delete`. To make this work, add the `app` folder to the autoload path:

```ruby
# config/application.rb
config.autoload_paths += [config.root.join('app')]
```

### Examples

The following service takes one or more users or user IDs as an argument.

```ruby
module Services
  module Users
    class Delete < Services::Base
      def call(ids_or_objects)
        users = find_objects(ids_or_objects)
        users.each do |user|
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
Services::Users::Delete.call User.where(id: [1, 2, 3])   # with multiple user objects
Services::Users::Delete.call 1                           # with a user ID
Services::Users::Delete.call [1, 2, 3]                   # with multiple user IDs

# Execute asynchronously/in the background
Services::Users::Delete.perform_async 1                  # with a user ID
Services::Users::Delete.perform_async [1, 2, 3]          # with multiple user IDs
```

As you can see, you cannot use objects when calling a service asynchronously since the arguments are serialized to Redis.

The helper `find_objects` is used to make sure you are dealing with an array of users from that point on, no matter whether `ids_or_objects` is a single user ID or user, or an array of user IDs or users.

It's good practice to always return the objects a service has been operating on at the end of the service.

Another example, this time using `Services::Query`:

```ruby
module Services
  module Users
    class Find < Services::Query
      private def process(scope, conditions)
        conditions.each do |k, v|
          case k
          when :email, :name
            scope = scope.where(k => v)
          when :product_id
            scope = scope.joins(:products).where("#{Product.table_name}.id" => v)
          when :product_category_id
            scope = scope.joins(:product_categories).where("#{ProductCategory.table_name}.id" => v)
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

Since you will create services to find objects for pretty much every model you have and they all look very similar, i.e. process the find conditions and return a `ActiveRecord::Relation`, you can let those services inherit from `Services::Query` to remove some of the boilerplate.

`Services::Query` takes an array of IDs and a hash of conditions as parameters. It then extracts some special conditions (:order, :limit, :page, :per_page) that are handled separately and passes a `ActiveRecord::Relation` and the remaining conditions to the `process` method that the inheriting class must define. This method should handle all the conditions, extend the scope and return it.

Check out [the source of `Services::Query`](lib/services/query.rb) to understand what it does in more detail.

### Helpers

Your services inherit from `Services::Base` which makes several helper methods available:

* `Rails.application.routes.url_helpers` is included so you use all Rails URL helpers.
* `find_objects` and `find_object` let you automatically find object or a single object from an array of objects or object IDs, or a single object or object ID. The only difference is that `find_object` returns a single object whereas `find_objects` always returns an array.
* `object_class` tries to figure out the class the service operates on. If you follow the service naming conventions and you have a service `Services::Products::Find`, `object_class` will return `Product`. Don't call it if you have a service like `Services::DoStuff` or it will raise an exception.

Your services also automatically get a custom `Error` class, so you can `raise Error, 'Uh-oh, something has gone wrong!'` and a `Services::MyService::Error` will be raised.

### Logging

You can choose between logging to Redis or to a file.

#### Redis

to be described...

#### File

to be described...

### Exception wrapping

to be described...

### Uniqueness checking

to be described...

### Background/asynchronous processing

to be described...

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
