# Server-to-server webhook endpoints, so this deliberately does not inherit
# from ApplicationController (no session, no require_login). Slack can't send
# a Rails CSRF token; it signs every request instead, which is what we verify.
module Slack
  class BaseController < ActionController::Base
    skip_forgery_protection

    before_action :verify_slack_signature!

    private

    def slack_client
      @slack_client ||= SlackNotifier.client
    end

    def verify_slack_signature!
      timestamp = request.headers["X-Slack-Request-Timestamp"].to_s
      signature = request.headers["X-Slack-Signature"].to_s
      secret = ENV["SLACK_SIGNING_SECRET"].to_s

      return head :unauthorized if secret.blank? || timestamp.blank? || signature.blank?
      # Replay protection: Slack's own guidance is to reject anything older than 5 minutes.
      return head :unauthorized if (Time.now.to_i - timestamp.to_i).abs > 300

      expected = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", secret, "v0:#{timestamp}:#{request.raw_post}")

      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end
  end
end
