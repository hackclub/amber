module Slack
  class EventsController < BaseController
    def create
      payload = JSON.parse(request.raw_post)

      case payload["type"]
      when "url_verification"
        render plain: payload["challenge"]
      when "event_callback"
        handle_event(payload["event"])
        head :ok
      else
        head :ok
      end
    end

    private

    def handle_event(event)
      return unless event["type"] == "app_home_opened"

      SlackHomeJob.perform_later(event["user"])
    end
  end
end
