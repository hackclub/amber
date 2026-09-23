class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :service
  belongs_to :topic

  has_many :notes, class_name: "TicketNote", dependent: :destroy

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, default: :low
  enum :status, { open: 0, in_progress: 1, done: 2, wont_do: 3 }, default: :open

  # humanize can't produce "Won't do", and "your ticket is now won't do"
  # doesn't parse — so labels and sentence forms both live here rather than
  # being reinvented by each of the web, Slack and MCP surfaces.
  STATUS_LABELS = {
    "open" => "Open",
    "in_progress" => "In progress",
    "done" => "Done",
    "wont_do" => "Won't do"
  }.freeze

  STATUS_SENTENCES = {
    "open" => "open again",
    "in_progress" => "in progress",
    "done" => "done",
    "wont_do" => "closed — won't do"
  }.freeze

  def self.status_label(status)
    STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  # [label, value] pairs for every select in the app.
  def self.status_options
    statuses.keys.map { |status| [ status_label(status), status ] }
  end

  def status_label
    self.class.status_label(status)
  end

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
