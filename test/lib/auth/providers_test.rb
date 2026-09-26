# frozen_string_literal: true

require "test_helper"

class Auth::ProvidersTest < ActiveSupport::TestCase
  def request_with(headers)
    ActionDispatch::TestRequest.create(headers.transform_keys { |h| "HTTP_#{h.upcase.tr('-', '_')}" })
  end

  # --- Google IAP（ES256, iss/aud 検証）--------------------------------------------------------

  def iap_provider(key_source: ->(_header) { @iap_key })
    @iap_key ||= OpenSSL::PKey::EC.generate("prime256v1")
    Auth::Providers::GcpIap.new(env: { "IAP_AUDIENCE" => "/projects/1/global/backendServices/2" }, key_source: key_source)
  end

  def iap_token(key: @iap_key, **overrides)
    payload = { "email" => "alice@example.com", "sub" => "accounts.google.com:123", "iss" => "https://cloud.google.com/iap",
                "aud" => "/projects/1/global/backendServices/2", "exp" => 5.minutes.from_now.to_i, "iat" => Time.now.to_i }.merge(overrides)
    JWT.encode(payload, key, "ES256", { "kid" => "k1" })
  end

  test "IAP: 正しく署名された JWT から身元を取り出す" do
    provider = iap_provider
    identity = provider.identify(request_with("X-Goog-IAP-JWT-Assertion" => iap_token))
    assert_equal "alice@example.com", identity.email
    assert_equal "gcp_iap", identity.provider
  end

  test "IAP: 別の鍵で署名された JWT は拒否する" do
    provider = iap_provider
    other = OpenSSL::PKey::EC.generate("prime256v1")
    assert_nil provider.identify(request_with("X-Goog-IAP-JWT-Assertion" => iap_token(key: other)))
  end

  test "IAP: 期限切れ・aud 不一致・iss 不一致は拒否する" do
    provider = iap_provider
    assert_nil provider.identify(request_with("X-Goog-IAP-JWT-Assertion" => iap_token("exp" => 1.minute.ago.to_i)))
    assert_nil provider.identify(request_with("X-Goog-IAP-JWT-Assertion" => iap_token("aud" => "/projects/9/global/backendServices/9")))
    assert_nil provider.identify(request_with("X-Goog-IAP-JWT-Assertion" => iap_token("iss" => "https://evil.example")))
  end

  test "IAP: メールヘッダだけで JWT が無い要求は認証しない（ヘッダ偽装対策）" do
    provider = iap_provider
    assert_nil provider.identify(request_with("X-Goog-Authenticated-User-Email" => "accounts.google.com:mallory@example.com"))
  end

  # --- AWS ALB（ES256, kid ごとの鍵、signer 検証）-------------------------------------------------

  test "ALB: kid で鍵を引いて検証し、ALB_ARN と signer を照合する" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    arn = "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:loadbalancer/app/x/abc"
    source = ->(header) { header["kid"] == "kid-1" ? key : raise(Auth::Error, "unknown kid") }
    provider = Auth::Providers::AwsAlb.new(env: { "ALB_REGION" => "ap-northeast-1", "ALB_ARN" => arn }, key_source: source)
    payload = { "email" => "bob@example.com", "exp" => 2.minutes.from_now.to_i }

    good = JWT.encode(payload, key, "ES256", { "kid" => "kid-1", "signer" => arn })
    assert_equal "bob@example.com", provider.identify(request_with("x-amzn-oidc-data" => good)).email

    unknown_kid = JWT.encode(payload, key, "ES256", { "kid" => "kid-2", "signer" => arn })
    assert_nil provider.identify(request_with("x-amzn-oidc-data" => unknown_kid))
  end

  test "ALB: signer が ALB_ARN と違えば拒否する" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    provider = Auth::Providers::AwsAlb.new(env: { "ALB_REGION" => "us-east-1", "ALB_ARN" => "arn:aws:elasticloadbalancing:us-east-1:1:loadbalancer/app/mine/1" }, key_source: ->(_) { key })
    provider.send(:key_source) # default_key_source を使わせないため先に固定
    token = JWT.encode({ "email" => "bob@example.com", "exp" => 2.minutes.from_now.to_i }, key, "ES256", { "kid" => "k", "signer" => "arn:aws:elasticloadbalancing:us-east-1:1:loadbalancer/app/other/2" })
    # key_source を差し替えたときは signer 検証も呼び出し側の責任なので、default_key_source の挙動を直接確かめる
    default_source = Auth::Providers::AwsAlb.new(env: { "ALB_REGION" => "us-east-1", "ALB_ARN" => "arn:expected" }).send(:default_key_source)
    assert_raises(Auth::Error) { default_source.call({ "kid" => "k", "signer" => "arn:other" }) }
    assert_not_nil provider.identify(request_with("x-amzn-oidc-data" => token))
  end

  # --- Cloudflare Access（RS256, JWKS）-----------------------------------------------------------

  test "Cloudflare Access: RS256 の JWT を team domain の issuer と aud で検証する" do
    key = OpenSSL::PKey::RSA.new(2048)
    provider = Auth::Providers::CloudflareAccess.new(env: { "CF_ACCESS_TEAM_DOMAIN" => "myteam.cloudflareaccess.com", "CF_ACCESS_AUD" => "aud-tag" }, key_source: ->(_) { key })
    payload = { "email" => "carol@example.com", "iss" => "https://myteam.cloudflareaccess.com", "aud" => [ "aud-tag" ], "exp" => 2.minutes.from_now.to_i }
    token = JWT.encode(payload, key, "RS256", { "kid" => "cf" })
    assert_equal "carol@example.com", provider.identify(request_with("Cf-Access-Jwt-Assertion" => token)).email

    wrong_aud = JWT.encode(payload.merge("aud" => [ "other" ]), key, "RS256", { "kid" => "cf" })
    assert_nil provider.identify(request_with("Cf-Access-Jwt-Assertion" => wrong_aud))
  end

  # --- Forwarded header / developer ---------------------------------------------------------------

  test "forwarded_header: ヘッダのメールをそのまま信用する（ヘッダ名は変更可）" do
    provider = Auth::Providers::ForwardedHeader.new(env: {})
    assert_equal "dave@example.com", provider.identify(request_with("X-Forwarded-Email" => "Dave@Example.com")).email
    assert_nil provider.identify(request_with({}))

    custom = Auth::Providers::ForwardedHeader.new(env: { "AUTH_EMAIL_HEADER" => "X-Auth-Request-Email" })
    assert_equal "erin@example.com", custom.identify(request_with("X-Auth-Request-Email" => "erin@example.com")).email
  end

  test "developer: production では明示しないと validate! で拒否する" do
    assert_raises(Auth::ConfigurationError) { Auth::Providers::Developer.new(env: {}, production: true).validate! }
    assert_nothing_raised { Auth::Providers::Developer.new(env: { "AUTH_ALLOW_DEVELOPER_IN_PRODUCTION" => "true" }, production: true).validate! }
    assert_nothing_raised { Auth::Providers::Developer.new(env: {}, production: false).validate! }
  end

  test "JWKS key source は kid で鍵を探し、見つからなければキャッシュを捨てて取り直す" do
    key = OpenSSL::PKey::RSA.new(2048)
    jwk = JWT::JWK.new(key, kid: "rot-2")
    jwks = { "keys" => [ jwk.export ] }.to_json
    source = Auth::KeySources::Jwks.new("https://example.test/jwks")
    calls = 0
    source.define_singleton_method(:fetch_text) { |_url, force: false| calls += 1; jwks }
    assert_equal key.public_key.to_pem, source.call({ "kid" => "rot-2" }).public_key.to_pem
    assert_raises(Auth::Error) { source.call({ "kid" => "missing" }) }
    assert_equal 3, calls
  end

  test "admin は ADMIN_EMAILS で決まる" do
    assert identity("admin@example.com").admin?
    assert_not identity("someone@example.com").admin?
  end
end
