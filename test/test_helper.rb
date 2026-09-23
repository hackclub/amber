ENV["RAILS_ENV"] ||= "test"
ENV["SLACK_SIGNING_SECRET"] ||= "test-signing-secret"
require_relative "../config/environment"
require "rails/test_help"

# Stands in for Slack::Web::Client, recording calls and returning the shapes
# the app actually reads back.
class FakeSlackClient
  attr_reader :calls

  def initialize(profile: nil)
    @calls = Hash.new { |hash, key| hash[key] = [] }
    @profile = profile || { name: "someone", profile: { real_name: "Some One", email: "someone@example.com" } }
  end

  def method_missing(name, **kwargs)
    @calls[name] << kwargs

    case name
    when :users_info then Hashie::Mash.new(user: @profile)
    when :chat_getPermalink then { "permalink" => "https://hackclub.slack.com/archives/C1/p1700000000" }
    else { "ok" => true }
    end
  end

  def respond_to_missing?(_name, _include_private = false) = true
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActionMailer::TestHelper

    # Minitest 6 dropped Object#stub, and this is the only seam we need.
    def with_slack_client(client = FakeSlackClient.new)
      original = SlackNotifier.method(:client)
      SlackNotifier.define_singleton_method(:client) { client }
      yield
    ensure
      SlackNotifier.define_singleton_method(:client, original)
    end
  end
end

module SlackRequestHelpers
  # Signs a request the way Slack does, so the controller's verification runs
  # for real in tests rather than being stubbed out.
  def slack_post(path, body, content_type: "application/x-www-form-urlencoded")
    timestamp = Time.now.to_i.to_s
    signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("SLACK_SIGNING_SECRET"), "v0:#{timestamp}:#{body}")

    post path, params: body, headers: {
      "CONTENT_TYPE" => content_type,
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature" => signature
    }
  end

  def interaction_body(payload)
    URI.encode_www_form(payload: payload.to_json)
  end
end
