require "test_helper"

# Every page, actually rendered. A route-helper typo or a bad view only shows
# up at render time, so each screen needs at least one request hitting it.
class PagesRenderTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  test "the signed-out landing page renders" do
    get root_path

    assert_response :success
    assert_select "form[action=?]", "/auth/hackclub"
  end

  test "every page a requester can reach renders" do
    sign_in(users(:requester))

    [ root_path, new_ticket_path, ticket_path(tickets(:website_bug)), settings_path ].each do |path|
      get path
      assert_response :success, "#{path} did not render"
    end
  end

  test "every page an admin can reach renders" do
    sign_in(users(:amber))

    [
      root_path,
      new_ticket_path,
      ticket_path(tickets(:website_bug)),
      settings_path,
      admin_services_path,
      edit_admin_service_path(services(:website)),
      edit_admin_topic_path(topics(:bug)),
      admin_users_path,
      admin_user_path(users(:requester))
    ].each do |path|
      get path
      assert_response :success, "#{path} did not render"
    end
  end

  test "a ticket page renders with a status note and a Slack requester" do
    users(:requester).update!(slack_id: "U123REQUESTER")
    tickets(:website_bug).update!(status_note: "Shipped this morning.")
    sign_in(users(:amber))

    get ticket_path(tickets(:website_bug))

    assert_response :success
    assert_match "Shipped this morning.", response.body
    assert_select "a[href*=?]", "slack.com/app_redirect?channel=U123REQUESTER"
  end
end
