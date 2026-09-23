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

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
