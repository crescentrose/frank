require 'open-uri'

# Abstraction layer to keep track of messages pending approval in memory
class PendingMessage
  class Attachment 
    class << self
      def open(url)
        new(URI.open(url), File.basename(url))
      end
    end
    
    def initialize(downloaded, name)
      @file = Tempfile.new(['kiracord', File.extname(name)])
      @file.write(downloaded.read)
      @file.rewind
      downloaded.close
    end

    def close
      @file.rewind # we do a little trolling
    end

    def close!
      @file.close
    end

    private

    # this is just a wrapper class so delegate all other methods to the one we are immitating
    def method_missing(method, *args, &block)
      @file.public_send(method, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @file.respond_to?(name, include_private)
    end
  end

  APPROVALS_CHANNEL = ENV.fetch('APPROVALS_CHANNEL_ID')
  SINK_CHANNEL = ENV.fetch('SINK_CHANNEL_ID')
  NSFW_CHANNEL = ENV.fetch('NSFW_CHANNEL_ID', SINK_CHANNEL)
  SERIOUS_CHANNEL = ENV.fetch('SERIOUS_CHANNEL_ID', SINK_CHANNEL)

  PENDING_REACTION = '☑️'
  APPROVED_REACTION = '✅'
  NSFW_REACTION = '🔞'
  REJECTED_REACTION = '⛔'
  UNDO_REACTION = '↩️'

  TRIPCODE_REGEX = /(\w+#\w+)\z/
  EMBED_COLOUR = Discordrb::ColourRGB.new(0x52394f)

  def initialize(origin:)
    @origin = origin
    @content = origin.content
    @attachments = origin.attachments.map { |a| Attachment.open(a.url) }
    @processed_at = nil
    @sink = nil
  end

  def propose(bot)
    # stupid api not using kwargs, have to pad out the fucking arguments
    @approver = bot.send_message(
      APPROVALS_CHANNEL,
      content,
      false, message_embed, attachments, nil, nil,
      approval_actions
    )

    origin_react(PENDING_REACTION)
  end

  def approve(bot, to: SINK_CHANNEL, react_with: APPROVED_REACTION)
    mark_processed!

    @sink = bot.send_message(
      to,
      content,
      false,
      message_embed,
      attachments
    )

    approver.react(react_with)
    origin_react(react_with)
  end

  def reject(react_with: REJECTED_REACTION)
    mark_processed!
    approver.react(react_with)
    origin_react(react_with)
  end

  def undo(bot)
    approver.react(UNDO_REACTION)
    sink.delete('undo confession send') unless sink.nil?
    unmark_processed! 
  end

  def id
    approver.id
  end

  def delete_outdated
    return false unless cleanupable?

    mark_final!
    true
  end

  def confirm_pending
    return false if processed_at.nil?

    mark_final!
    true
  end

  private

  attr_reader :origin, :approver, :attachments, :processed_at, :sink

  def cleanupable?
    return false if processed_at.nil?

    Time.now - processed_at > 15 # seconds to undo
  end

  def content
    @content.strip.gsub(TRIPCODE_REGEX, '')
  end

  # sign message with User#password 
  def signature
    @signature ||= if @content.strip =~ TRIPCODE_REGEX
                     code = Tripcode.parse($1)
                     "#{code[0]}!#{code[1]}"
                   else
                     ''
                   end
  end

  def message_embed
    return nil if signature.empty?

    Discordrb::Webhooks::Embed.new(
      colour: EMBED_COLOUR,
      description: "✅ message signed by #{signature}"
    )
  end

  def approval_actions
    actions = Discordrb::Webhooks::View.new
    actions.row do |row|
      row.button style: :success, label: 'Approve', custom_id: 'approve'
      row.button style: :secondary, label: 'NSFW', custom_id: 'nsfw'
      row.button style: :secondary, label: 'Serious', custom_id: 'serious'
      row.button style: :danger, label: 'Reject', custom_id: 'reject'
    end

    actions
  end

  def undo_action
    actions = Discordrb::Webhooks::View.new
    actions.row do |row|
      row.button style: :secondary, label: 'Undo', custom_id: 'undo'
    end

    actions
  end

  def mark_processed!
    @processed_at = Time.now
    approver.edit(content, message_embed, undo_action)
  end

  def unmark_processed!
    @processed_at = nil
    approver.edit(content, message_embed, approval_actions)
  end

  def mark_final!
    approver.edit(content, message_embed, [])
  ensure
    attachments.each(&:close!)
  end

  def origin_react(reaction)
    origin.delete_own_reaction('☑️') unless reaction == PENDING_REACTION
    origin.react(reaction)
  rescue Discordrb::Errors::UnknownMessage => e
    # we don't care if the op deleted their message before it was approved
  end
end
