# An OAuth client, created by dynamic client registration (RFC 7591) when
# something like Claude's connector UI first points at this server.
class OauthClient < ApplicationRecord
  has_many :oauth_grants, dependent: :delete_all
  has_many :oauth_tokens, dependent: :delete_all

  validates :client_id, presence: true, uniqueness: true
  validates :name, presence: true
  validate :redirect_uris_are_usable

  def self.register!(name:, redirect_uris:, public_client: true)
    client = new(
      client_id: SecureRandom.uuid,
      name: name.presence || "Unnamed client",
      redirect_uris: Array(redirect_uris)
    )

    secret = nil
    unless public_client
      secret = SecureRandom.urlsafe_base64(32)
      client.client_secret_digest = Digests.of(secret)
    end

    client.save!
    [ client, secret ]
  end

  def confidential?
    client_secret_digest.present?
  end

  def authenticates_with?(secret)
    return true unless confidential?

    secret.present? && ActiveSupport::SecurityUtils.secure_compare(client_secret_digest, Digests.of(secret))
  end

  # OAuth 2.1: exact match only, no prefix or wildcard matching.
  def allows?(redirect_uri)
    redirect_uris.include?(redirect_uri)
  end

  private

  def redirect_uris_are_usable
    if redirect_uris.blank?
      errors.add(:redirect_uris, "must include at least one URI")
      return
    end

    redirect_uris.each do |uri|
      parsed = URI.parse(uri)
      next if parsed.is_a?(URI::HTTPS)
      # Loopback redirects are how native and CLI clients receive the code.
      next if parsed.is_a?(URI::HTTP) && [ "localhost", "127.0.0.1", "::1" ].include?(parsed.host)

      errors.add(:redirect_uris, "must be https, or http on loopback: #{uri}")
    rescue URI::InvalidURIError
      errors.add(:redirect_uris, "is not a valid URI: #{uri}")
    end
  end
end
