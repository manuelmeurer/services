# Services

[![Gem Version](https://badge.fury.io/rb/services.png)](http://badge.fury.io/rb/services)
[![Build Status](https://secure.travis-ci.org/krautcomputing/services.png)](http://travis-ci.org/krautcomputing/services)
[![Dependency Status](https://gemnasium.com/krautcomputing/services.png)](https://gemnasium.com/krautcomputing/services)
[![Code Climate](https://codeclimate.com/github/krautcomputing/services.png)](https://codeclimate.com/github/krautcomputing/services)

Services is a collection of modules and base classes that let you implement a nifty service layer in your Rails app.

## Motivation

A lot has been written about service layers in Rails apps. There are advantages and disadvantages of course, but after using Services since 2013 in several Rails apps, I must say that in my opinion the advantages far outweigh the disadvantages.

**The biggest benefit you get with a service layer is that it makes it much easier to reason about your application, find a bug, or implement new features, when all your business logic is in services, not scattered in models, controllers, helpers etc.**

## Usage

For disambiguation, we let's write Services with a uppercase S when we mean this gem, and services with a lowercase s when we mean, well, the plural of service.

### Basic principles

Services is based on a couple of basic principles of what a service should be and do in your Rails app:

* a service does one thing well (Unix philosophy)
* a service can be run synchronously (in the foreground) or asynchronously (in the background)
* a service can be unique, meaning only one instance of it should be run at a time
* a service logs all the things (start time, end time, caller, exceptions etc.)
* a service has its own exception class and all exceptions that it may raise must be of that class or a subclass
* a service can be called with one or multiple objects or one or multiple object IDs

Apart from these basic principles, you can implement the actual logic in a service any way you want.

### Conventions

Follow these conventions that Services expects/recommends:

* services inherit from `Services::Base` (or `Services::BaseFinder`)
* services are located in `app/services/`
* services are namespaced with the model they operate on and their names are verbs, e.g. `app/services/users/delete.rb` defines `Services::Users::Delete`. If a service operates on multiple models or no models at all, don't namespace them (`Services::DoLotsOfStuff`) or namespace them by logical groups unrelated to models (`Services::Maintenance::CleanOldUsers`, `Services::Maintenance::SendDailySummary`, etc.)
* Sometimes services must call other services. Try to not combine multiple calls to other services and business logic in one service. Instead, some services should contain only business logic and other services only a bunch of service calls but no (or little) business logic. This keeps your services nice and modular.

### Dependence

To process services in the background, Services uses [Sidekiq](https://github.com/mperham/sidekiq). Sidekiq is not absolutely required to use Services though, if it's not present, a service will raise an exception when you try to enqueue it for background processing. If you're using Sidekiq, make sure to load the Services gem after the Sidekiq gem.

The SQL `Services::BaseFinder` (discussed further down) generates is optimized for Postgres. It might work with other databases but it's not guaranteed. If you're not using Postgres, don't use `Services::BaseFinder` or, even better, submit a PR that fixes it to work with your database!

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

As you can see, the helper `find_objects` is used to make sure you are dealing with an array of users from that point on, no matter whether `ids_or_objects` is a single user ID or user, or an array of user IDs or users.

It's good practice to always return the objects a service has been operating on at the end of the service.

Another example, this time using `Services::BaseFinder`:

```ruby
module Services
  module Users
    class Find < Services::BaseFinder
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

Since you will create services to find objects for pretty much every model you have and they all look very similar, i.e. process the find conditions and return a `ActiveRecord::Relation`, you can let those services inherit from `Services::BaseFinder` to remove some of the boilerplate.

`Services::BaseFinder` inherits from `Services::Base` and takes an array of IDs and a hash of conditions as parameters. It then extracts some special conditions (:order, :limit, :page, :per_page) that are handled separately and passes a `ActiveRecord::Relation` and the remaining conditions to the `process` method that the inheriting class must define. This method should handle all the conditions, extend the scope and return it.

Check out [the source of `Services::BaseFinder`](lib/services/base_finder.rb) to understand what it does in more detail.

### Helpers

Your services inherit from `Services::Base` which makes several helper methods available:

* `Rails.application.routes.url_helpers` is included so you use all Rails URL helpers.
* `find_objects` and `find_object` let you automatically find object or a single object from an array of objects or object IDs, or a single object or object ID. The only difference is that `find_object` returns a single object whereas `find_objects` always returns an array.
* `object_class` tries to figure out the class the service operates on. If you follow the service naming conventions and you have a service `Services::Products::Find`, `object_class` will return `Product`. Don't call it if you have a service like `Services::DoStuff` or it will raise an exception.
* `controller` creates a `ActionController::Base` instance with an empty request. You can use it to call `render_to_string` to render a view from your service for example.

Your services also automatically get a custom `Error` class, so you can `raise Error, 'Uh-oh, something has gone wrong!'` and a `Services::MyService::Error` will be raised.

### Logging

to be described...

### Exception wrapping

to be described...

### Uniqueness checking

to be described...

### Background/asynchronous processing

to be described...

## Requirements

Ruby >= 2.0

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
