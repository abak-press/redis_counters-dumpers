source 'https://rubygems.org'

# Specify your gem's dependencies in redis_counters-dumpers.gemspec

group :development, :test do
  gem 'combustion', github: 'pat/combustion', ref: '7d0d24c3f36ce0eb336177fc493be0721bc26665'
  gem 'activerecord-postgres-hstore', require: false
  gem 'simple_hstore_accessor', '~> 0.2', require: false
end

gem 'rack', '< 2' if RUBY_VERSION < '2.2.0'

gemspec
