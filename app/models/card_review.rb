# Almacena el estado SM-2 de una tarjeta para un usuario concreto.
# El cálculo del algoritmo en sí vive en Sm2Calculator; este modelo solo
# aplica el resultado y lo persiste.
class CardReview < ApplicationRecord
  belongs_to :card
  belongs_to :user

  has_many :review_logs, dependent: :destroy

  validates :repetitions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :interval, presence: true, numericality: { greater_than: 0 }
  validates :easiness, presence: true, numericality: { greater_than_or_equal_to: 1.3 }
  validates :next_review_at, presence: true

  scope :due, -> { where("next_review_at <= ?", Time.current) }
  scope :pending, -> { order(:next_review_at) }

  # @param quality [Integer]
  # @return [Boolean] true si se guardó correctamente
  def apply_review!(quality)
    result = Sm2Calculator.new(
      repetitions: repetitions,
      interval:    interval,
      easiness:    easiness,
      quality:     quality
    ).call

    self.repetitions    = result.repetitions
    self.interval       = result.interval
    self.easiness       = result.easiness
    self.next_review_at = result.next_review_at

    save!
    review_logs.create!(quality: quality, reviewed_at: Time.current)
  end

  def due?
    next_review_at <= Time.current
  end
end
