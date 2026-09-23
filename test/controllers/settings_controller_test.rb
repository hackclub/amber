require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  test "signing out users can't see settings" do
    get settings_path

    assert_redirected_to root_path
  end

  test "the settings page renders for someone with no token yet" do
    sign_in(users(:requester))

    get settings_path

    assert_response :success
    assert_select "form[action=?]", api_token_settings_path
    assert_match "claude mcp add", response.body
  end

  test "generating a token shows it once and stores only its digest" do
    sign_in(users(:requester))

    post api_token_settings_path
    follow_redirect!

    assert_response :success
    token = response.body[/tkt_[A-Za-z0-9_-]+/]
    assert token.present?, "expected the raw token to be shown once"

    user = users(:requester).reload
    assert user.api_token?
    refute_equal token, user.api_token_digest
    assert_equal user, User.authenticate_api_token(token)
  end

  test "the page renders again afterwards without re-showing the token" do
    sign_in(users(:requester))
    post api_token_settings_path
    follow_redirect!

    get settings_path

    assert_response :success
    assert_match "A token is active", response.body
    assert_no_match(/tkt_[A-Za-z0-9_-]{20,}/, response.body)
  end

  test "revoking a token stops it authenticating" do
    sign_in(users(:requester))
    token = users(:requester).regenerate_api_token!

    delete api_token_settings_path

    assert_redirected_to settings_path
    refute users(:requester).reload.api_token?
    assert_nil User.authenticate_api_token(token)
  end

  test "an admin sees the queue examples" do
    sign_in(users(:amber))

    get settings_path

    assert_response :success
    assert_match "What's on my plate?", response.body
  end
end
