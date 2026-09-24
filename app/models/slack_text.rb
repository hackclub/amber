# Slack message text isn't plain text: & < > arrive HTML-escaped, and links,
# channels and mentions come wrapped in angle brackets. Pasting it straight
# into a ticket shows things like "&amp;" and "<#C09N1P69GKZ>", so it gets
# converted to markdown on the way in.
module SlackText
  ENTITIES = { "&amp;" => "&", "&lt;" => "<", "&gt;" => ">" }.freeze

  def self.to_markdown(text, client: nil)
    return "" if text.blank?

    names = Names.new(client)

    # Markup tokens use real angle brackets, so they're parsed before
    # entities are unescaped — otherwise a literal "&lt;" the person typed
    # would start looking like markup.
    unescape(text.to_s.gsub(/<([^<>]+)>/) { token($1, names) })
  end

  # Opens the channel, or a DM with the person, in whichever Slack client
  # they use. Same redirect the "Message on Slack" link uses.
  def self.deep_link(id)
    url = "https://slack.com/app_redirect?channel=#{id}"
    team = ENV["SLACK_TEAM_ID"].presence

    team ? "#{url}&team=#{team}" : url
  end

  def self.token(inner, names)
    body, label = inner.split("|", 2)

    case body
    when /\A@([UW][A-Z0-9]+)\z/i then mention("@#{label.presence || names.user(body[1..])}", body[1..])
    when /\A#(C[A-Z0-9]+)\z/i then mention("##{label.presence || names.channel(body[1..])}", body[1..])
    when /\A!(here|channel|everyone)\z/ then "@#{Regexp.last_match(1)}"
    when /\A!subteam\^/ then label.presence || "@group"
    when /\Amailto:(.+)\z/ then label.presence || Regexp.last_match(1)
    else
      url = unescape(body)
      label.present? && label != body ? "[#{unescape(label)}](#{url})" : url
    end
  end
  private_class_method :token

  # Markdown so it renders as a link like any other, rather than needing
  # special treatment downstream. Brackets in a name would break the link
  # syntax, so they're dropped.
  def self.mention(label, id)
    "[#{label.tr('[]', '')}](#{deep_link(id)})"
  end
  private_class_method :mention

  def self.unescape(text)
    text.gsub(/&amp;|&lt;|&gt;/, ENTITIES)
  end

  # Looks up the names behind bare IDs, once each, and falls back to the ID
  # rather than failing a ticket over a missing scope.
  class Names
    def initialize(client)
      @client = client
      @cache = {}
    end

    def user(id)
      resolve(id) do
        profile = @client.users_info(user: id).user
        profile.profile.display_name.presence || profile.profile.real_name.presence || profile.name
      end
    end

    def channel(id)
      resolve(id) { @client.conversations_info(channel: id).channel.name }
    end

    private

    def resolve(id)
      return id if @client.nil?

      @cache[id] ||= yield.presence || id
    rescue StandardError => e
      Rails.logger.info("Slack lookup failed for #{id}: #{e.class}")
      id
    end
  end
end
