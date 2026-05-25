# Almacena el estado SM-2 de una tarjeta para un usuario concreto.
# Integra la lógica del algoritmo directamente en el modelo.
class CardReview < ApplicationRecord
  belongs_to :card
  belongs_to :user

  validates :repetitions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :interval, presence: true, numericality: { greater_than: 0 }
  validates :easiness, presence: true, numericality: { greater_than_or_equal_to: 1.3 }
  validates :next_review_at, presence: true

  scope :due, -> { where("next_review_at <= ?", Time.current) }
  scope :pending, -> { order(:next_review_at) }

  # @param quality [Integer]
  # @return [Boolean] true si se guardó correctamente
  def apply_review!(quality)
    raise ArgumentError, "quality debe ser 0..5, recibido: #{quality}" unless (0..5).cover?(quality)

    if quality < 3
      self.repetitions    = 0
      self.interval       = 1
    else
      self.easiness    = updated_easiness(quality)
      self.interval    = next_interval
      self.repetitions = repetitions + 1
    end

    self.next_review_at = Time.current + interval.days
    save!
  end

  def due?
    next_review_at <= Time.current
  end

  private

  def updated_easiness(quality)
    # Fórmula original de Wozniak (SM-2, 1987), calibrada empíricamente.
    # El castigo es cuadrático: cuanto peor la calificación, mayor la penalización.
    new_easiness = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
    [ 1.3, easiness + new_easiness ].max.round(4)
  end

  def next_interval
    case repetitions
    when 0 then 1
    when 1 then 6
    else (interval * easiness).round
    end
  end
end
