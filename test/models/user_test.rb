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

  test "admin is synced from ADMIN_EMAILS on login" do
    auth = OmniAuth::AuthHash.new(uid: "sub_admin_sync", info: { email: "amber@hackclub.com", name: "Amber" })

    user = User.from_omniauth(auth)

    assert user.admin?
  end
end
