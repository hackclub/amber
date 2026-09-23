# A short-lived authorization code, bound to the client, redirect URI and PKCE
# challenge it was issued for. Single use.
class OauthGrant < ApplicationRecord
  LIFETIME = 10.minutes

  belongs_to :oauth_client
  belongs_to :user

  scope :usable, -> { where(expires_at: Time.current..) }

  def self.issue!(client:, user:, redirect_uri:, code_challenge:, scope:, resource: nil)
    code = "mcp_ac_#{SecureRandom.urlsafe_base64(32)}"

    create!(
      oauth_client: client,
      user: user,
      code_digest: Digests.of(code),
      redirect_uri: redirect_uri,
      code_challenge: code_challenge,
      scope: scope,
      resource: resource,
      expires_at: LIFETIME.from_now
    )

    code
  end

  # Redeeming is destructive: a code that's been exchanged (or replayed) is gone.
  def self.redeem!(code:, client:, redirect_uri:, code_verifier:)
    grant = usable.find_by(code_digest: Digests.of(code), oauth_client: client)
    return if grant.nil?

    grant.destroy
    return unless grant.redirect_uri == redirect_uri
    return unless grant.verifies?(code_verifier)

    grant
  end

  # PKCE S256 only — OAuth 2.1 drops "plain".
  def verifies?(code_verifier)
    return false if code_verifier.blank?

    expected = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(code_verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(code_challenge.to_s, expected)
  end
end
