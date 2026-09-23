class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :service
  belongs_to :topic

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, default: :medium
  enum :status, { open: 0, in_progress: 1, done: 2 }, default: :open

  validates :title, presence: true
  validates :message, presence: true
  validate :topic_belongs_to_service
  validate :url_must_be_http_or_https

  scope :needs_attention, -> { where(status: [ :open, :in_progress ]) }
  scope :ordered_for_admin, -> {
    joins(:user).order(Arel.sql("users.priority_boost DESC, tickets.priority DESC, tickets.created_at ASC"))
  }

  private

  def topic_belongs_to_service
    return if topic.blank? || service.blank?

    errors.add(:topic, "must belong to the selected service") if topic.service_id != service_id
  end

  def url_must_be_http_or_https
    return if url.blank?

    uri = URI.parse(url)
    errors.add(:url, "must be a valid http(s) URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid URL")
  end
end
