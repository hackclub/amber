require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "priority_boost defaults to true for hackclub.com emails on creation" do
    auth = OmniAuth::AuthHash.new(
      uid: "sub_new_hc",
      info: { email: "new@hackclub.com", name: "New Person" }
    )

    user = User.from_omniauth(auth)

    assert user.priority_boost?
  end

  test "priority_boost defaults to false for other emails on creation" do
    auth = OmniAuth::AuthHash.new(
      uid: "sub_new_other",
      info: { email: "new@example.com", name: "New Person" }
    )

    user = User.from_omniauth(auth)

    refute user.priority_boost?
  end

  test "priority_boost is not overwritten on subsequent logins" do
    user = users(:requester)
    user.update!(priority_boost: true)

    auth = OmniAuth::AuthHash.new(uid: user.sub, info: { email: user.email, name: user.name })
    User.from_omniauth(auth)

    assert user.reload.priority_boost?
  end

  test "find_or_create_from_slack matches an existing user on Slack ID" do
    existing = users(:amber)

    found = with_slack_client { User.find_or_create_from_slack(existing.slack_id, SlackNotifier.client) }

    assert_equal existing, found
  end

  test "find_or_create_from_slack never matches on email" do
    existing = users(:requester)
    client = FakeSlackClient.new(profile: { name: "someone", profile: { real_name: "Some One", email: existing.email } })

    created = with_slack_client(client) { User.find_or_create_from_slack("U-brand-new", SlackNotifier.client) }

    refute_equal existing, created
    assert_equal "U-brand-new", created.slack_id
    assert_equal "slack:U-brand-new", created.sub
  end

  test "find_or_create_from_slack applies the hackclub.com priority boost" do
    client = FakeSlackClient.new(profile: { name: "hc", profile: { real_name: "HC Person", email: "hc@hackclub.com" } })

    created = with_slack_client(client) { User.find_or_create_from_slack("U-hc", SlackNotifier.client) }

    assert created.priority_boost?
  end

  test "ADMIN_SLACK_IDS grants admin without a web sign-in" do
    created = with_slack_client { User.find_or_create_from_slack("U054VC2KM9P", SlackNotifier.client) }

    assert created.admin?
  end

  test "signing in later merges into the Slack-created user instead of duplicating" do
    slack_user = with_slack_client { User.find_or_create_from_slack("U-merge-me", SlackNotifier.client) }

    auth = OmniAuth::AuthHash.new(
      uid: "oidc-sub-123",
      info: { email: "merged@hackclub.com", name: "Merged Person", slack_id: "U-merge-me" }
    )

    assert_no_difference -> { User.count } do
      User.from_omniauth(auth)
    end

    slack_user.reload
    assert_equal "oidc-sub-123", slack_user.sub
    assert_equal "merged@hackclub.com", slack_user.email
  end

  test "admin is synced from ADMIN_EMAILS on login" do
    auth = OmniAuth::AuthHash.new(uid: "sub_admin_sync", info: { email: "amber@hackclub.com", name: "Amber" })

    user = User.from_omniauth(auth)

    assert user.admin?
  end
end
