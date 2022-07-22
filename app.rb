#!/usr/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'discordrb', github: 'shardlab/discordrb', branch: 'main' # discord API, dev version
  gem 'tripcode', '~> 1.0.1' # 4chan compatible tripcodes
  gem 'dotenv', require: 'dotenv/load' # load config from .env file
end

bot = Discordrb::Bot.new(token: ENV.fetch('DISCORD_BOT_TOKEN'))
approvals_channel = ENV.fetch('APPROVALS_CHANNEL_ID')
sink_channel = ENV.fetch('SINK_CHANNEL_ID')

pending_messages = {}
PendingMessage = Struct.new(:origin, :approval, :content, keyword_init: true)

bot.direct_message do |dm|
  approval_actions = Discordrb::Webhooks::View.new
  approval_actions.row do |row|
    row.button style: :success, label: 'Approve', custom_id: 'approve'
    row.button style: :danger, label: 'Reject', custom_id: 'reject'
  end

  # stupid api not using kwargs
  message = bot.send_message(
    approvals_channel,
    dm.message.content,
    false, nil, nil, nil, nil,
    approval_actions
  )

  dm.message.react('✔️')
  pending_messages[message.id] = PendingMessage.new(origin: dm.message, approval: message, content: dm.message.content)
end

bot.button(custom_id: 'approve') do |event|
  message = pending_messages[event.message.id]
  next if message.nil?

  bot.send_message(
    sink_channel,
    message.content
  )
  message.origin.delete_own_reaction('✔️')
  message.approval.edit(message.content, nil, [])
  event.defer_update 
  pending_messages[event.message.id] = nil
  message.origin.react('✅')
  message.approval.react('✅')
end

bot.button(custom_id: 'reject') do |event|
  message = pending_messages[event.message.id]
  next if message.nil?

  message.origin.delete_own_reaction('✔️')
  message.approval.edit(message.content, nil, [])
  event.defer_update 
  pending_messages[event.message.id] = nil
  message.origin.react('⛔')
  message.approval.react('⛔')
end

bot.run
