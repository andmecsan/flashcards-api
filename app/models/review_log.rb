class ReviewLog < ApplicationRecord
  belongs_to :card_review

  validates :quality,     presence: true,
                          inclusion: { in: 0..5, message: "debe ser entre 0 y 5" }
  validates :reviewed_at, presence: true
end
