#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'discordrb', github: 'shardlab/discordrb', branch: 'main' # discord API, dev version
  gem 'tripcode', '~> 1.0.1' # 4chan compatible tripcodes
  gem 'dotenv' # load config from .env file
end

# load appropriate application configuration
APP_ENV = ENV.fetch("APP_ENV", "production")
Dotenv.load(".env.#{APP_ENV}", '.env')

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
  pending_messages.delete(event.message.id)
  event.defer_update # we don't respond with a message, so just let discord know we are live 
end

bot.button(custom_id: 'nsfw') do |event|
  message = pending_messages.delete(event.message.id)
  next if message.nil?

  message.approve(bot, to: PendingMessage::NSFW_CHANNEL, react_with: PendingMessage::NSFW_REACTION)
  event.defer_update
end

bot.button(custom_id: 'serious') do |event|
  message = pending_messages.delete(event.message.id)
  next if message.nil?

  message.approve(bot, to: PendingMessage::SERIOUS_CHANNEL)
  event.defer_update
end

bot.button(custom_id: 'reject') do |event|
  message = pending_messages.delete(event.message.id)
  next if message.nil?

  message.reject
  event.defer_update 
end

begin
  bot.run
rescue Interrupt => e
  unless pending_messages.empty?
    pending_messages.each { |id, message| message.reject(react_with: '💤') }
    bot.send_message(
      PendingMessage::APPROVALS_CHANNEL,
      "💤 Flushing #{pending_messages.size} messages from the queue due to bot shutdown. All pending messages were rejected.",
    )
  end
  bot.stop
end 
