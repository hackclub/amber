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

  test "channel mentions become readable names that link back to Slack" do
    assert_equal "in [#hcb-grants](https://slack.com/app_redirect?channel=C09N1P69GKZ)",
                 SlackText.to_markdown("in <#C09N1P69GKZ>", client: client)
    assert_equal "in [#shipped](https://slack.com/app_redirect?channel=C09N1P69GKZ)",
                 SlackText.to_markdown("in <#C09N1P69GKZ|shipped>", client: client)
  end

  test "user mentions become readable names that link back to Slack" do
    assert_equal "ask [@amber](https://slack.com/app_redirect?channel=U054VC2KM9P)",
                 SlackText.to_markdown("ask <@U054VC2KM9P>", client: client)
  end

  test "mentions include the workspace when one is configured" do
    with_env("SLACK_TEAM_ID" => "T0266FRGM") do
      assert_includes SlackText.to_markdown("<#C09N1P69GKZ>", client: client), "&team=T0266FRGM"
    end
  end

  test "ids survive when there's no client to resolve them" do
    assert_equal "in [#C09N1P69GKZ](https://slack.com/app_redirect?channel=C09N1P69GKZ)",
                 SlackText.to_markdown("in <#C09N1P69GKZ>")
  end

  test "a failed lookup falls back to the id instead of blowing up" do
    exploding = Object.new
    def exploding.conversations_info(*) = raise(StandardError, "missing_scope")

    assert_includes SlackText.to_markdown("in <#C09N1P69GKZ>", client: exploding), "#C09N1P69GKZ"
  end

  test "a name containing brackets can't break the link syntax" do
    weird = FakeSlackClient.new(profile: { name: "x", profile: { display_name: "we[ird]" } })

    result = SlackText.to_markdown("ask <@U1>", client: weird)

    assert_equal "ask [@weird](https://slack.com/app_redirect?channel=U1)", result
  end

  test "recognises a Slack permalink" do
    assert SlackText.permalink?("https://hackclub.slack.com/archives/C0AR0M43H61/p1790186475464309?thread_ts=1")
    refute SlackText.permalink?("https://example.com/archives/C1/p1")
    refute SlackText.permalink?("https://hackclub.slack.com/team/U1")
    refute SlackText.permalink?(nil)
  end

  test "names the channel a permalink points at" do
    url = "https://hackclub.slack.com/archives/C0AR0M43H61/p1790186475464309"

    assert_equal "#hcb-grants", SlackText.permalink_channel(url, client: client)
  end

  test "a DM permalink names who it's with when the token can see that" do
    url = "https://hackclub.slack.com/archives/D086UU94KHR/p1790105752663349"

    assert_equal "a DM with @amber", SlackText.permalink_channel(url, client: client)
  end

  test "a DM the token can't see into still reads sensibly" do
    blind = Object.new
    def blind.conversations_info(*) = Hashie::Mash.new(channel: { id: "D1" })

    url = "https://hackclub.slack.com/archives/D086UU94KHR/p1790105752663349"
    assert_equal "a DM", SlackText.permalink_channel(url, client: blind)
  end

  test "an unresolvable channel degrades instead of showing an id" do
    exploding = Object.new
    def exploding.conversations_info(*) = raise(StandardError, "channel_not_found")

    url = "https://hackclub.slack.com/archives/C0AR0M43H61/p1790186475464309"
    assert_equal "Slack", SlackText.permalink_channel(url, client: exploding)
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
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
