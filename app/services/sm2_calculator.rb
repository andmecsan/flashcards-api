# Cálculo puro del algoritmo SM-2 (Wozniak, 1987): a partir del estado actual
# de una tarjeta y la calificación de un repaso, devuelve el nuevo estado sin
# persistir nada.
class Sm2Calculator
  MINIMUM_EASINESS = 1.3

  Result = Struct.new(:repetitions, :interval, :easiness, :next_review_at, keyword_init: true)

  def initialize(repetitions:, interval:, easiness:, quality:, now: Time.current)
    raise ArgumentError, "quality debe ser 0..5, recibido: #{quality}" unless (0..5).cover?(quality)

    @repetitions = repetitions
    @interval    = interval
    @easiness    = easiness
    @quality     = quality
    @now         = now
  end

  def call
    if @quality < 3
      Result.new(repetitions: 0, interval: 1, easiness: @easiness, next_review_at: @now + 1.day)
    else
      new_easiness = updated_easiness
      new_interval = next_interval(new_easiness)

      Result.new(
        repetitions:    @repetitions + 1,
        interval:       new_interval,
        easiness:       new_easiness,
        next_review_at: @now + new_interval.days
      )
    end
  end

  private

  def updated_easiness
    # Fórmula original de Wozniak (SM-2, 1987), calibrada empíricamente.
    # El castigo es cuadrático: cuanto peor la calificación, mayor la penalización.
    delta = 0.1 - (5 - @quality) * (0.08 + (5 - @quality) * 0.02)
    [ MINIMUM_EASINESS, @easiness + delta ].max.round(4)
  end

  def next_interval(new_easiness)
    case @repetitions
    when 0 then 1
    when 1 then 6
    else (@interval * new_easiness).round
    end
  end
end
