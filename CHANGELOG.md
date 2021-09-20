## 9.0.0

* Drop support for Rails 5.2 and Ruby 2.6
* Exclude test files from release
* Add CI via GitHub Actions
* Make replacing ActiveRecord records in asyncable params more robust
* When calling a service async, make args and kwargs available as ivars

## 8.0.1

* add missing `to_s`

## 8.0.0

* handle kwargs correctly
* test with current rails versions

## 7.3.3

* fix typo
* increase cache time to 30 days

## 7.3.1

* fix loading background processor

## 7.3.0

* allow using sucker_punch instead of sidekiq
* allow setting the method arity when allowing class method to be used in queries, since scopes shadow the arity of their procs

## 7.2.0

* enable using class methods in queries

## 7.1.2

* use select instead of pluck

## 7.1.1

* fix typos

## 7.1.0

* fix joining order classes
* refactor, formatting

## 7.0.3

* fix identifying call method when calling service async
* remove gemnasium badge
* fix "buy me a coffee" link
* add "buy me a coffee" link to readme

## 7.0.2

* symbolize hash keys for arguments to call method when kwargs are used
* dont modify args
* fix spec
* fix specs and readme

## 7.0.1

* add table name to condition

## 7.0.0

* add created_after and created_before as default conditions, allow overriding default conditions in query object

## 6.0.5

* Revert "set default order for query if it was set to nil"

## 6.0.4

* automatically add LEFT OUTER JOIN when trying to sort by a field on an association table
* set default order for query if it was set to nil

## 6.0.3

* allow calling query service without params

## 6.0.2

* add id_not as special query condition

## 6.0.1

* allow calling query object with only arguments
* update sidekiq dev dependency to 5.x
* remove encoding comment
* add missing require
* syntax

## 6.0.0

* dont specify ruby patchlevels in travis config
* use globalid to make args serializable
* remove bulk call async method
* remove async instance methods from services

## 5.1.2

* dup passed in scope in query class before using it
* fix specs for ruby < 2.4
* update rails 5.1 to released version
* update travis config
* stop supporting rails 4.0 and 4.1, add 5.1.rc1

## 5.1.1

* replace Fixnum with Integer to silence Ruby 2.4 warnings
* update ruby versions in travis config
* update travis config
* update ruby versions in travis config
* update travis build matrix, dont test ruby 2.4.0 with rails 4.0 or 4.1, allow ruby 2.4.0 with rails 4.2 to fail for now (until rails 4.2.8 is released with
out json 1.x dependency)
* increase sleep and waiting time in specs
* require active_record explicitly
* fix specs

## 5.1.0

* test with ruby 2.4.0, clarify version requirements for ruby and redis
* update sidekiq dev dependency to ~> 4.0
* allow passing scope to query call

## 5.0.0

* freeze constants
* use #public_send instead of #send where possible
* rename perform_* methods to call_*, closes #6

## 4.3.0

* update travis config
* use pluck only on activerecord relations, from activesupport 5 on all enumerables respond to #pluck, which will call #[] on the contained objects [Manuel M
eurer]
* drop support for rails 3.2, add appraisal for testing
* update readme
* update ruby dependency in readme
* update travis config

## 4.1.4

* update changelog
* fix finding find service class

## 4.1.3

* Fix finding the find service class

## 4.1.2

* Make "Services" namespace optional when determining object class

## 4.1.1

* Try to determine Redis connection from `Redis.current` if not explicitly set in configuration

## 4.1.0

* Add possibility to automatically convert condition objects to IDs in query

## 4.0.2

* Add null logger

## 4.0.1

* Account for that `redis.multi` can return nil

## 4.0.0

* Remove host configuration and controller method

## 3.1.1

* Query does not have its own error, raise ArgumentError instead
* Verify that query ids parameter is not nil

## 3.0.1

* Fix for Ruby 2.0

## 3.0.0

* Rename `BaseFinder` to `Query`
* `Query` doesn't inherit from `Base` anymore
* Only use SQL subquery in `Query` if a JOIN is used

## 2.2.4

* Increase TTL for Redis keys for uniqueness and error count to one day
* Fix ordering in `BaseFinder`

## 2.2.3

* Add `on_error` option `return` to uniqueness checker

## 2.1.0

* Add `find_ids` and `find_id` helpers to base service

## 2.0.2

* Make BaseFinder smarter, don't create SQL subquery if not necessary

## 2.0.1

* Fix disabling call logging

## 2.0.0

* Improve call logging
* Implement `disable_call_logging` and `enable_call_logging` to control call logging for specific services
* Disable call logging for `BaseFinder` by default
* Rename `check_uniqueness!` to `check_uniqueness`

## 1.3.0

* Allow only certain classes in Redis logger meta (NilClass, TrueClass, FalseClass, Symbol, String, Numeric)

## 1.2.0

* Convert log time to time object when fetching logs

## 1.1.1

* When logging to Redis, convert all values to strings first

## 1.1.0

* Change arguments for log call in file and Redis logger, replace tag array with meta hash
* Add methods to query size of logs and fetch logs to Redis logger

## 1.0.0

* First stable version
