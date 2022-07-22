# Abstraction layer to keep track of messages pending approval in memory
class PendingMessage
  APPROVALS_CHANNEL = ENV.fetch('APPROVALS_CHANNEL_ID')
  SINK_CHANNEL = ENV.fetch('SINK_CHANNEL_ID')

  PENDING_REACTION = '☑️'
  APPROVED_REACTION = '✅'
  REJECTED_REACTION = '⛔'

  TRIPCODE_REGEX = /(\w+#\w+)\z/

  def initialize(origin:)
    @origin = origin
    @content = origin.content
  end

  def propose(bot)
    # stupid api not using kwargs, have to pad out the fucking arguments
    @approver = bot.send_message(
      APPROVALS_CHANNEL,
      content,
      false, nil, nil, nil, nil,
      approval_actions
    )

    origin_react(PENDING_REACTION)
  end

  def approve(bot)
    mark_processed!

    bot.send_message(
      SINK_CHANNEL,
      content,
    )

    approver.react(APPROVED_REACTION)
    origin_react(APPROVED_REACTION)
  end

  def reject
    mark_processed!
    approver.react(REJECTED_REACTION)
    origin_react(REJECTED_REACTION)
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
    if @content.strip =~ TRIPCODE_REGEX
      code = Tripcode.parse($1)
      "**#{code[0]}!#{code[1]}**"
    else
      ''
    end
  end

  def approval_actions
    actions = Discordrb::Webhooks::View.new
    actions.row do |row|
      row.button style: :success, label: 'Approve', custom_id: 'approve'
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
