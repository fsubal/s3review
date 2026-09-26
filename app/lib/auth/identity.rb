# frozen_string_literal: true

module Auth
  # 認証済みの人。コメントの creator にそのまま載る
  Identity = Struct.new(:email, :name, :provider, keyword_init: true) do
    def self.from_claims(claims, provider:)
      email = claims["email"].to_s.strip.downcase
      return nil if email.empty?

      new(email: email, name: claims["name"].presence || email, provider: provider)
    end

    def admin? = Auth.admin?(email)
    def role = admin? ? "admin" : "reviewer"

    def as_json(*)
      { "email" => email, "name" => name, "provider" => provider, "role" => role }
    end
  end
end
