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

* Added Redis logger
* Moved file logger to separate class
* Don't initialize file logger automatically for Rails apps anymore
* Changed argument order for Redis and file logger, made `tags` parameter optional

## 0.4.0

* Renamed `service_class` helper to `object_class`

## 0.3.4

* Added `BaseFinder`
* Updated uniqueness key
