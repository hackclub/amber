class OauthToken < ApplicationRecord
  ACCESS_TOKEN_LIFETIME = 24.hours

  belongs_to :oauth_client
  belongs_to :user

  scope :active, -> { where(revoked_at: nil) }

  def self.issue!(client:, user:, scope:)
    access = "mcp_at_#{SecureRandom.urlsafe_base64(32)}"
    refresh = "mcp_rt_#{SecureRandom.urlsafe_base64(32)}"

    token = create!(
      oauth_client: client,
      user: user,
      scope: scope,
      access_token_digest: Digests.of(access),
      refresh_token_digest: Digests.of(refresh),
      expires_at: ACCESS_TOKEN_LIFETIME.from_now
    )

    [ token, access, refresh ]
  end

  def self.authenticate(access_token)
    return if access_token.blank?

    active.where(expires_at: Time.current..).find_by(access_token_digest: Digests.of(access_token))
  end

  def self.find_by_refresh_token(refresh_token)
    return if refresh_token.blank?

    active.find_by(refresh_token_digest: Digests.of(refresh_token))
  end

  # Refreshing rotates the access token but keeps the refresh token, so a
  # connector that's been sitting idle doesn't need the user to re-approve.
  def refresh!
    access = "mcp_at_#{SecureRandom.urlsafe_base64(32)}"
    update!(access_token_digest: Digests.of(access), expires_at: ACCESS_TOKEN_LIFETIME.from_now)
    access
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def expires_in
    [ (expires_at - Time.current).to_i, 0 ].max
  end
end
