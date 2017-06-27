source 'https://rubygems.org'

# Versions can be overridden with environment variables for matrix testing.
# Travis will remove Gemfile.lock before installing deps. As such, it is
# advisable to pin major versions in this Gemfile.
group :puppet do
  gem 'puppet', ENV['PUPPET_VERSION'] || '~> 3.6.0'
  gem 'facter', ENV['FACTER_VERSION'] || '~> 2.1.0'
  gem 'hiera',  ENV['HIERA_VERSION']  || '~> 1.3.0'
end

group :test do
  gem 'puppet-syntax', '~> 2.1.0'
  gem 'puppet-lint', '~> 1.1.0'
  gem 'librarian-puppet', '2.2.3'
  gem 'puppet_forge', '2.2.4'
  gem 'colorize', '>= 0.7.5'
  gem 'open4', '>= 1.3.4'
end
