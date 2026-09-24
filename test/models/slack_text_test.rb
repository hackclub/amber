require "test_helper"

class SlackTextTest < ActiveSupport::TestCase
  def client
    @client ||= FakeSlackClient.new
  end

  test "unescapes the entities Slack escapes" do
    assert_equal "a & b < c > d", SlackText.to_markdown("a &amp; b &lt; c &gt; d")
  end

  test "a query string keeps its ampersands" do
    url = "https://hackclub.slack.com/archives/C1/p123?thread_ts=1.2&channel=C1&message_ts=3.4"

    assert_equal url, SlackText.to_markdown("<#{url.gsub('&', '&amp;')}>")
  end

  test "a labelled link becomes a markdown link" do
    assert_equal "see [the thread](https://example.com/x)",
                 SlackText.to_markdown("see <https://example.com/x|the thread>")
  end

  test "a bare link is left for autolink to pick up" do
    assert_equal "at https://example.com/x", SlackText.to_markdown("at <https://example.com/x>")
  end

  test "channel mentions become readable names" do
    assert_equal "in #hcb-grants", SlackText.to_markdown("in <#C09N1P69GKZ>", client: client)
    assert_equal "in #shipped", SlackText.to_markdown("in <#C09N1P69GKZ|shipped>", client: client)
  end

  test "user mentions become readable names" do
    assert_equal "ask @amber", SlackText.to_markdown("ask <@U054VC2KM9P>", client: client)
    assert_equal "ask @someone", SlackText.to_markdown("ask <@U054VC2KM9P|someone>", client: client)
  end

  test "ids survive when there's no client to resolve them" do
    assert_equal "in #C09N1P69GKZ", SlackText.to_markdown("in <#C09N1P69GKZ>")
    assert_equal "ask @U054VC2KM9P", SlackText.to_markdown("ask <@U054VC2KM9P>")
  end

  test "a failed lookup falls back to the id instead of blowing up" do
    exploding = Object.new
    def exploding.conversations_info(*) = raise(StandardError, "missing_scope")

    assert_equal "in #C09N1P69GKZ", SlackText.to_markdown("in <#C09N1P69GKZ>", client: exploding)
  end

  test "broadcasts read as mentions" do
    assert_equal "@here and @channel", SlackText.to_markdown("<!here> and <!channel>")
  end

  test "a literal angle bracket the user typed is left alone" do
    assert_equal "use <div> tags", SlackText.to_markdown("use &lt;div&gt; tags")
  end

  test "blank text stays blank" do
    assert_equal "", SlackText.to_markdown(nil)
    assert_equal "", SlackText.to_markdown("")
  end

  test "the real-world message from a Slack shortcut comes out clean" do
    raw = "just wondering if you could fulfill the grants i asked for in <#C09N1P69GKZ> " \
          "using my leftover cookies? <https://hackclub.enterprise.slack.com/archives/C09N1P69GKZ/p178?" \
          "thread_ts=1787584598.437019&amp;channel=C09N1P69GKZ>"

    result = SlackText.to_markdown(raw, client: client)

    assert_no_match(/&amp;/, result)
    assert_no_match(/<#/, result)
    assert_includes result, "#hcb-grants"
    assert_includes result, "thread_ts=1787584598.437019&channel=C09N1P69GKZ"
  end
end
