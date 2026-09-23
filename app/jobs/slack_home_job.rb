class SlackHomeJob < ApplicationJob
  queue_as :default

  def perform(slack_user_id)
    SlackNotifier.publish_home(slack_user_id)
  end
end
