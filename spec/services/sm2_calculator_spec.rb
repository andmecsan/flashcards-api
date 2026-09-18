require "rails_helper"

RSpec.describe Sm2Calculator do
  let(:now) { Time.zone.parse("2026-01-01 12:00:00") }

  describe "#call con calificación correcta (q >= 3)" do
    context "primera revisión (repetitions = 0, q = 5)" do
      subject(:result) do
        described_class.new(repetitions: 0, interval: 1, easiness: 2.5, quality: 5, now: now).call
      end

      it "establece el intervalo a 1 día" do
        expect(result.interval).to eq(1)
      end

      it "incrementa repetitions a 1" do
        expect(result.repetitions).to eq(1)
      end

      it "sube el easiness por encima de 2.5" do
        expect(result.easiness).to be > 2.5
      end

      it "programa el próximo repaso exactamente 1 día después" do
        expect(result.next_review_at).to eq(now + 1.day)
      end
    end

    context "segunda revisión (repetitions = 1, q = 4)" do
      subject(:result) do
        described_class.new(repetitions: 1, interval: 1, easiness: 2.6, quality: 4, now: now).call
      end

      it "establece el intervalo a 6 días" do
        expect(result.interval).to eq(6)
      end

      it "incrementa repetitions a 2" do
        expect(result.repetitions).to eq(2)
      end

      it "mantiene el easiness neutro con q=4" do
        expect(result.easiness).to be_within(0.01).of(2.6)
      end
    end

    context "tercera revisión en adelante (repetitions >= 2)" do
      subject(:result) do
        described_class.new(repetitions: 2, interval: 6, easiness: 2.5, quality: 4, now: now).call
      end

      it "multiplica el intervalo por el easiness" do
        expect(result.interval).to eq((6 * 2.5).round)
      end

      it "incrementa repetitions a 3" do
        expect(result.repetitions).to eq(3)
      end
    end
  end

  describe "#call con calificación fallida (q < 3)" do
    subject(:result) do
      described_class.new(repetitions: 5, interval: 30, easiness: 2.5, quality: 2, now: now).call
    end

    it "reinicia repetitions a 0" do
      expect(result.repetitions).to eq(0)
    end

    it "reinicia interval a 1" do
      expect(result.interval).to eq(1)
    end

    it "mantiene el easiness acumulado" do
      expect(result.easiness).to eq(2.5)
    end

    it "programa el próximo repaso para mañana" do
      expect(result.next_review_at).to eq(now + 1.day)
    end
  end

  describe "clamp del easiness" do
    it "nunca baja de 1.3 aunque se falle muchas veces" do
      easiness = 2.5
      repetitions = 0
      interval = 1

      20.times do
        result = described_class.new(
          repetitions: repetitions, interval: interval, easiness: easiness, quality: 3, now: now
        ).call
        repetitions = result.repetitions
        interval    = result.interval
        easiness    = result.easiness
      end

      expect(easiness).to be >= 1.3
    end
  end

  describe "crecimiento del intervalo" do
    it "crece exponencialmente con repasos perfectos" do
      easiness = 2.5
      repetitions = 0
      interval = 1
      intervals = []

      5.times do
        result = described_class.new(
          repetitions: repetitions, interval: interval, easiness: easiness, quality: 5, now: now
        ).call
        repetitions = result.repetitions
        interval    = result.interval
        easiness    = result.easiness
        intervals << interval
      end

      expect(intervals).to eq(intervals.sort)
      expect(intervals.last).to be > intervals.first * 5
    end
  end

  describe "validación de quality" do
    it "lanza ArgumentError si quality es mayor de 5" do
      expect {
        described_class.new(repetitions: 0, interval: 1, easiness: 2.5, quality: 6)
      }.to raise_error(ArgumentError)
    end

    it "lanza ArgumentError si quality es negativo" do
      expect {
        described_class.new(repetitions: 0, interval: 1, easiness: 2.5, quality: -1)
      }.to raise_error(ArgumentError)
    end
  end
end
