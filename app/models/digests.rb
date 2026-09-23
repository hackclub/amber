# Secrets (tokens, codes, client secrets) are only ever stored hashed.
module Digests
  def self.of(value)
    OpenSSL::Digest::SHA256.hexdigest(value.to_s)
  end
end
