#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'discordrb', github: 'shardlab/discordrb', branch: 'main' # discord API, dev version
  gem 'tripcode', '~> 1.0.1' # 4chan compatible tripcodes
  gem 'dotenv', require: 'dotenv/load' # load config from .env file
end

require_relative 'pending_message.rb'

bot = Discordrb::Bot.new(token: ENV.fetch('DISCORD_BOT_TOKEN'))

pending_messages = {}

bot.direct_message do |event|
  message = PendingMessage.new(origin: event.message)
  message.propose(bot)
  pending_messages[message.id] = message
end

bot.button(custom_id: 'approve') do |event|
  message = pending_messages[event.message.id]
  next if message.nil?

  message.approve(bot)
  event.defer_update # we don't respond with a message, so just let discord know we are live 
  pending_messages[event.message.id] = nil
end

bot.button(custom_id: 'reject') do |event|
  message = pending_messages[event.message.id]
  next if message.nil?

  message.reject
  event.defer_update 
  pending_messages[event.message.id] = nil
end

bot.run
