# frozen_string_literal: true

ENV['APP_ENV'] = 'test'
ENV['DATABASE_PATH'] = ':memory:'

require 'rack/test'
require_relative '../app'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.before do
    LavaTrucks::Database.reset!
    header 'Host', 'localhost' if respond_to?(:app)
  end
end
