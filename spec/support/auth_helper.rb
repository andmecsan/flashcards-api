module AuthHelper
  def auth_headers(user)
    token = JwtService.encode({ user_id: user.id })
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end