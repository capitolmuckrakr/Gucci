require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'gucci'

RSpec.configure do |config|
  config.mock_framework = :mocha
end