require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "slack_dm_url opens a DM with someone who has a Slack ID" do
    url = slack_dm_url(users(:amber))

    assert_includes url, "https://slack.com/app_redirect?channel=U000AMBER"
  end

  test "slack_dm_url includes the team when one is configured" do
    with_env("SLACK_TEAM_ID" => "T0266FRGM") do
      assert_includes slack_dm_url(users(:amber)), "team=T0266FRGM"
    end
  end

  test "slack_dm_url is nil for someone who has never used Slack here" do
    assert_nil slack_dm_url(users(:requester))
    assert_nil slack_dm_url(nil)
  end

  test "markdown links open in a new tab" do
    html = markdown("See [the docs](https://example.com/docs)")

    assert_includes html, %(target="_blank")
    assert_includes html, %(rel="noopener noreferrer")
  end

  test "bare urls are autolinked and open in a new tab too" do
    html = markdown("it's at https://example.com/thing")

    assert_includes html, %(href="https://example.com/thing")
    assert_includes html, %(target="_blank")
  end

  test "markdown never turns a javascript url into a link" do
    html = markdown("[click me](javascript:alert)")

    # Redcarpet leaves it as plain text rather than linking it, so what
    # matters is that no anchor carries the scheme.
    assert_no_match(/<a[^>]*javascript/i, html)
    assert_no_match(/<a /, html)
  end

  test "markdown still strips raw html" do
    html = markdown("<script>alert(1)</script><b>hi</b>")

    assert_no_match(/<script/, html)
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
