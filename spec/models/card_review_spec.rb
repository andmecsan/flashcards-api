# spec/models/card_review_spec.rb
require "rails_helper"

RSpec.describe CardReview, type: :model do
  let(:user) { User.create!(name: "Andrea", email: "andrea@test.com", uid: "google-123") }
  let(:deck) { Deck.create!(name: "SM-2", user: user) }
  let(:card) { Card.create!(front: "¿Qué es SM-2?", back: "Un algoritmo de repaso espaciado", deck: deck) }

  let(:fresh_review) do
    CardReview.create!(
      card:           card,
      user:           user,
      repetitions:    0,
      interval:       1,
      easiness:       2.5,
      next_review_at: Time.current
    )
  end

  describe "validaciones" do
    it "es válido con atributos correctos" do
      expect(fresh_review).to be_valid
    end

    it "no permite easiness menor de 1.3" do
      fresh_review.easiness = 1.2
      expect(fresh_review).not_to be_valid
    end

    it "no permite repetitions negativas" do
      fresh_review.repetitions = -1
      expect(fresh_review).not_to be_valid
    end

    it "requiere next_review_at" do
      fresh_review.next_review_at = nil
      expect(fresh_review).not_to be_valid
    end
  end

  # ── apply_review! — calificaciones correctas (q >= 3) ────────────────────

  describe "#apply_review! con calificación correcta" do
    context "primera revisión (repetitions = 0, q = 5)" do
      before { fresh_review.apply_review!(5) }

      it "establece el intervalo a 1 día" do
        expect(fresh_review.interval).to eq(1)
      end

      it "incrementa repetitions a 1" do
        expect(fresh_review.repetitions).to eq(1)
      end

      it "sube el easiness por encima de 2.5" do
        expect(fresh_review.easiness).to be > 2.5
      end

      it "programa el próximo repaso en ~1 día" do
        expect(fresh_review.next_review_at).to be_within(1.minute).of(1.day.from_now)
      end
    end

    context "segunda revisión (repetitions = 1, q = 4)" do
      before do
        fresh_review.apply_review!(5)  # primera revisión
        fresh_review.apply_review!(4)  # segunda revisión
      end

      it "establece el intervalo a 6 días" do
        expect(fresh_review.interval).to eq(6)
      end

      it "incrementa repetitions a 2" do
        expect(fresh_review.repetitions).to eq(2)
      end

      it "mantiene el easiness neutro con q=4" do
        # q=4 es el punto de equilibrio — el EF no sube ni baja
        expect(fresh_review.easiness).to be_within(0.01).of(2.6) # sube por el q=5 anterior
      end
    end

    context "tercera revisión en adelante (repetitions >= 2)" do
      let(:experienced_review) do
        CardReview.create!(
          card:           card,
          user:           user,
          repetitions:    2,
          interval:       6,
          easiness:       2.5,
          next_review_at: Time.current
        )
      end

      before { experienced_review.apply_review!(4) }

      it "multiplica el intervalo por el easiness" do
        expect(experienced_review.interval).to eq((6 * 2.5).round) # => 15
      end

      it "incrementa repetitions a 3" do
        expect(experienced_review.repetitions).to eq(3)
      end
    end
  end

  # ── apply_review! — calificaciones fallidas (q < 3) ──────────────────────

  describe "#apply_review! con calificación fallida" do
    let(:experienced_review) do
      CardReview.create!(
        card:           card,
        user:           user,
        repetitions:    5,
        interval:       30,
        easiness:       2.5,
        next_review_at: Time.current
      )
    end

    before { experienced_review.apply_review!(2) }

    it "reinicia repetitions a 0" do
      expect(experienced_review.repetitions).to eq(0)
    end

    it "reinicia interval a 1" do
      expect(experienced_review.interval).to eq(1)
    end

    it "mantiene el easiness acumulado" do
      # El EF no se toca en los fallos — solo se actualiza en los aciertos
      expect(experienced_review.easiness).to eq(2.5)
    end

    it "programa el próximo repaso para mañana" do
      expect(experienced_review.next_review_at).to be_within(1.minute).of(1.day.from_now)
    end
  end

  # ── Clamp del easiness ────────────────────────────────────────────────────

  describe "clamp del easiness" do
    it "nunca baja de 1.3 aunque se falle muchas veces" do
      review = fresh_review
      20.times { review.apply_review!(3) }
      expect(review.easiness).to be >= 1.3
    end
  end

  # ── Crecimiento exponencial del intervalo ─────────────────────────────────

  describe "crecimiento del intervalo" do
    it "crece exponencialmente con repasos perfectos" do
      review = fresh_review
      intervals = []

      5.times do
        review.apply_review!(5)
        intervals << review.interval
      end

      # Cada intervalo debe ser mayor que el anterior
      expect(intervals).to eq(intervals.sort)
      # El último intervalo debe ser significativamente mayor que el primero
      expect(intervals.last).to be > intervals.first * 5
    end
  end

  # ── Validación del argumento quality ─────────────────────────────────────

  describe "validación de quality" do
    it "lanza ArgumentError si quality es mayor de 5" do
      expect { fresh_review.apply_review!(6) }.to raise_error(ArgumentError)
    end

    it "lanza ArgumentError si quality es negativo" do
      expect { fresh_review.apply_review!(-1) }.to raise_error(ArgumentError)
    end
  end

  # ── due? ──────────────────────────────────────────────────────────────────

  describe "#due?" do
    it "devuelve true si next_review_at es en el pasado" do
      fresh_review.update!(next_review_at: 1.day.ago)
      expect(fresh_review.due?).to be true
    end

    it "devuelve false si next_review_at es en el futuro" do
      fresh_review.update!(next_review_at: 1.day.from_now)
      expect(fresh_review.due?).to be false
    end
  end
end
