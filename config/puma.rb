# frozen_string_literal: true
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', '8000')}"
environment ENV.fetch('RACK_ENV', 'development')
threads 0, 5
workers 0
