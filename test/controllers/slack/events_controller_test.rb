require "test_helper"

class Slack::EventsControllerTest < ActionDispatch::IntegrationTest
  include SlackRequestHelpers

  test "answers the url_verification challenge" do
    slack_post slack_events_path,
               { type: "url_verification", challenge: "abc123" }.to_json,
               content_type: "application/json"

    assert_response :success
    assert_equal "abc123", response.body
  end

  test "publishes the Home tab when it is opened" do
    assert_enqueued_with job: SlackHomeJob, args: [ "U054VC2KM9P" ] do
      slack_post slack_events_path,
                 { type: "event_callback", event: { type: "app_home_opened", user: "U054VC2KM9P" } }.to_json,
                 content_type: "application/json"
    end

    assert_response :success
  end

  test "rejects an unsigned request" do
    post slack_events_path,
         params: { type: "url_verification", challenge: "abc123" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized
  end
end
