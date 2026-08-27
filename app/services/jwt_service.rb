class JwtService
  SECRET = Rails.application.credentials.jwt[:secret]
  EXPIRATION = 24.hours.from_now.to_i

  def self.encode(payload)
    payload[:exp] = EXPIRATION
    JWT.encode(payload, SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  rescue JWT::DecodeError
    nil
  end
end
