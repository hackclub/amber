module ApplicationHelper
  MARKDOWN_RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, hard_wrap: true),
    autolink: true,
    fenced_code_blocks: true,
    tables: true,
    no_intra_emphasis: true
  )

  def markdown(text)
    sanitize(MARKDOWN_RENDERER.render(text.to_s), tags: %w[p br strong em a ul ol li h1 h2 h3 h4 blockquote code pre table thead tbody tr th td hr del], attributes: %w[href])
  end

  # Returns nil when the user has no Slack ID yet (no external image service
  # is called in that case) — pair with #avatar_initial for a local fallback.
  def avatar_url(user)
    "https://cachet.hackclub.com/users/#{user.slack_id}/r" if user&.slack_id.present?
  end

  # Opens a Slack DM with this person in whichever Slack client they use.
  def slack_dm_url(user)
    return if user&.slack_id.blank?

    url = "https://slack.com/app_redirect?channel=#{user.slack_id}"
    team = ENV["SLACK_TEAM_ID"].presence
    team ? "#{url}&team=#{team}" : url
  end

  def avatar_initial(user)
    (user&.name.presence || user&.email.to_s).to_s.first.to_s.upcase.presence || "?"
  end

  def avatar_tag(user, css_class: "size-8 rounded-full")
    if (url = avatar_url(user))
      image_tag(url, alt: user.name.to_s, class: css_class)
    else
      content_tag(:div, avatar_initial(user), class: "#{css_class} bg-red-500 text-white flex items-center justify-center font-semibold shrink-0")
    end
  end

  PRIORITY_CLASSES = {
    "low" => "bg-gray-100 text-gray-700",
    "medium" => "bg-blue-100 text-blue-700",
    "high" => "bg-orange-100 text-orange-700",
    "urgent" => "bg-red-100 text-red-700"
  }.freeze

  STATUS_CLASSES = {
    "open" => "bg-yellow-100 text-yellow-800",
    "in_progress" => "bg-blue-100 text-blue-800",
    "done" => "bg-green-100 text-green-800",
    "wont_do" => "bg-gray-200 text-gray-600"
  }.freeze

  # Ticket#url is validated to be http(s) already, but re-checking at render
  # time keeps the view safe even if that ever changes.
  def safe_http_url(url)
    uri = URI.parse(url.to_s)
    url if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  # Shared box styling for text/select/textarea inputs. Tailwind's `border-*`
  # color utilities need a `border` width utility alongside them or nothing
  # renders — easy to drop, so it's centralized here instead of repeated.
  def input_classes(extra = nil)
    "block w-full rounded-md border border-gray-300 bg-white px-3 py-2 shadow-sm " \
    "focus:border-red-500 focus:ring-1 focus:ring-red-500 focus:outline-none #{extra}".strip
  end

  def priority_badge_classes(priority)
    PRIORITY_CLASSES.fetch(priority.to_s, "bg-gray-100 text-gray-700")
  end

  def status_badge_classes(status)
    STATUS_CLASSES.fetch(status.to_s, "bg-gray-100 text-gray-700")
  end
end
