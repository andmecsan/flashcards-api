class User < ApplicationRecord
  has_secure_password validations: false

  has_many :decks,        dependent: :destroy
  has_many :card_reviews, dependent: :destroy

  validates :name,     presence: true
  validates :email,    presence: true, uniqueness: true,
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  def self.from_omniauth(auth)
    user = find_by(uid: auth.uid)
    return user if user

    user = find_by(email: auth.info.email)
    if user
      user.update!(uid: auth.uid)
      return user
    end

    create!(
      name:  auth.info.name,
      email: auth.info.email,
      uid:   auth.uid
    )
  end
end
