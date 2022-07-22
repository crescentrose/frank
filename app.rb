#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'discordrb', '~> 3.4' # discord API
  gem 'tripcode', '~> 1.0.1' # 4chan compatible tripcodes
  gem 'dotenv', require: 'dotenv/load' # load config from .env file
end

bot = Discordrb::Bot.new(token: ENV.fetch('DISCORD_BOT_TOKEN'))

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
