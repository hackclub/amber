class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :service
  belongs_to :topic

  has_many :notes, class_name: "TicketNote", dependent: :destroy

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, default: :low
  enum :status, { open: 0, in_progress: 1, done: 2, not_doing: 3 }, default: :open

  # "Your ticket is now #{status.humanize.downcase}" reads badly for not_doing,
  # so each state gets a phrase that fits in a sentence.
  STATUS_SENTENCES = {
    "open" => "open again",
    "in_progress" => "in progress",
    "done" => "done",
    "not_doing" => "closed as not planned"
  }.freeze

  def status_sentence
    STATUS_SENTENCES.fetch(status, status.humanize.downcase)
  end

  validates :title, presence: true
  validates :message, presence: true
  validate :topic_belongs_to_service
  validate :url_must_be_http_or_https

  scope :needs_attention, -> { where(status: [ :open, :in_progress ]) }
  scope :ordered_for_admin, -> {
    joins(:user).order(Arel.sql("users.priority_boost DESC, tickets.priority DESC, tickets.created_at ASC"))
  }

  # Notifications live here rather than in the controllers so tickets filed
  # from Slack notify identically to ones filed on the web.
  after_create_commit :notify_created
  after_update_commit :notify_status_changed, if: :saved_change_to_status?

  private

  def notify_created
    TicketMailer.created(self).deliver_later
    SlackNotificationJob.perform_later(id, "created")
  end

  def notify_status_changed
    TicketMailer.status_changed(self).deliver_later
    SlackNotificationJob.perform_later(id, "status_changed")
  end

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
