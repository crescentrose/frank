#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'discordrb', '~> 3.4' # discord API
  gem 'tripcode', '~> 1.0.1' # 4chan compatible tripcodes
  gem 'dotenv', require: 'dotenv/load' # load config from .env file
end

bot = Discordrb::Bot.new(token: ENV.fetch('DISCORD_BOT_TOKEN'))
approvals_channel = ENV.fetch('APPROVALS_CHANNEL_ID')
sink_channel = ENV.fetch('SINK_CHANNEL_ID')

bot.direct_message do |dm|
  bot.send_message(approvals_channel, dm.message)
end

bot.run
