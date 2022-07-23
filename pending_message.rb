# Abstraction layer to keep track of messages pending approval in memory
class PendingMessage
  APPROVALS_CHANNEL = ENV.fetch('APPROVALS_CHANNEL_ID')
  SINK_CHANNEL = ENV.fetch('SINK_CHANNEL_ID')
  NSFW_CHANNEL = ENV.fetch('NSFW_CHANNEL_ID')

  PENDING_REACTION = '☑️'
  APPROVED_REACTION = '✅'
  NSFW_REACTION = '🔞'
  REJECTED_REACTION = '⛔'

  TRIPCODE_REGEX = /(\w+#\w+)\z/
  TRIPCODE_COLOUR = Discordrb::ColourRGB.new(0x20f200)

  def initialize(origin:)
    @origin = origin
    @content = origin.content
  end

  def propose(bot)
    # stupid api not using kwargs, have to pad out the fucking arguments
    @approver = bot.send_message(
      APPROVALS_CHANNEL,
      content,
      false, signature_embed, nil, nil, nil,
      approval_actions
    )

    origin_react(PENDING_REACTION)
  end

  def approve(bot, to: SINK_CHANNEL, react_with: APPROVED_REACTION)
    mark_processed!

    bot.send_message(
      to,
      content,
      false,
      signature_embed
    )

    approver.react(react_with)
    origin_react(react_with)
  end

  def reject(react_with: REJECTED_REACTION)
    mark_processed!
    approver.react(react_with)
    origin_react(react_with)
  end

  def id
    approver.id
  end
  
  private

  attr_reader :origin, :approver

  def content
    @content.strip.gsub(TRIPCODE_REGEX, '') + signature
  end

  # sign message with User#password 
  def signature
    @signature ||= if @content.strip =~ TRIPCODE_REGEX
                     code = Tripcode.parse($1)
                     "**#{code[0]}!#{code[1]}**"
                   else
                     ''
                   end
  end

  def signature_embed
    return nil if signature.empty?

    Discordrb::Webhooks::Embed.new(description: "✅ message signed")
  end

  def approval_actions
    actions = Discordrb::Webhooks::View.new
    actions.row do |row|
      row.button style: :success, label: 'Approve', custom_id: 'approve'
      row.button style: :secondary, label: 'NSFW', custom_id: 'nsfw'
      row.button style: :danger, label: 'Reject', custom_id: 'reject'
    end

    actions
  end

  def mark_processed!
    approver.edit(content, nil, []) # remove buttons
  end

  def origin_react(reaction)
    origin.delete_own_reaction('☑️') unless reaction == PENDING_REACTION
    origin.react(reaction)
  rescue Discordrb::Errors::UnknownMessage => e
    # we don't care if the op deleted their message before it was approved
  end
end
