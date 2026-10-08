require "rails_helper"

RSpec.describe Card, type: :model do
  describe ".due_for" do
    let(:user)  { create(:user) }
    let(:other) { create(:user, email: "otro@test.com") }
    let(:card)  { create(:card, category: create(:category, deck: create(:deck, user: user))) }

    def review_for(card, owner, next_review_at:)
      CardReview.create!(
        card: card, user: owner,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: next_review_at
      )
    end

    it "incluye las tarjetas que el usuario nunca ha estudiado" do
      expect(Card.due_for(user)).to include(card)
    end

    it "incluye la tarjeta si la review del usuario ya venció" do
      review_for(card, user, next_review_at: 1.hour.ago)

      expect(Card.due_for(user)).to include(card)
    end

    it "excluye la tarjeta si la review del usuario es futura" do
      review_for(card, user, next_review_at: 3.days.from_now)

      expect(Card.due_for(user)).not_to include(card)
    end

    it "sigue contando como nueva para el usuario aunque otro ya la haya estudiado" do
      review_for(card, other, next_review_at: 3.days.from_now)

      expect(Card.due_for(user)).to include(card)
    end

    it "no devuelve la tarjeta duplicada cuando hay reviews de varios usuarios" do
      review_for(card, user, next_review_at: 1.hour.ago)
      review_for(card, other, next_review_at: 1.hour.ago)

      expect(Card.due_for(user).where(id: card.id).count).to eq(1)
    end
  end
end
