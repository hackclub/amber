class User < ApplicationRecord
  has_many :tickets, dependent: :destroy

  validates :sub, presence: true, uniqueness: true
  validates :email, presence: true

  def self.admin_emails
    ENV.fetch("ADMIN_EMAILS", "amber@hackclub.com").split(",").map { |e| e.strip.downcase }
  end

  # Builds/updates a User from the omniauth.auth hash set by either the
  # real :hackclub (OpenID Connect) strategy or the development-only
  # :developer fallback strategy.
  def self.from_omniauth(auth)
    user = find_or_initialize_by(sub: auth.uid)
    user.email = auth.info.email
    user.name = auth.info.name
    user.slack_id = extract_slack_id(auth) || user.slack_id
    user.priority_boost = user.email.to_s.end_with?("@hackclub.com") if user.new_record?
    user.admin = admin_emails.include?(user.email.to_s.downcase)
    user.save!
    user
  end

  def self.extract_slack_id(auth)
    auth.info["slack_id"] || auth.extra&.raw_info&.slack_id
  end
  private_class_method :extract_slack_id
end
