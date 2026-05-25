class User < ApplicationRecord
  has_many :decks,        dependent: :destroy
  has_many :card_reviews, dependent: :destroy

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :uid,   presence: true, uniqueness: true

  def self.from_omniauth(auth)
    find_or_create_by(uid: auth.uid) do |user|
      user.name  = auth.info.name
      user.email = auth.info.email
    end
  end
end