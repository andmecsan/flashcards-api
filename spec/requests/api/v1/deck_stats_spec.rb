require "rails_helper"

RSpec.describe "Api::V1::Deck Stats", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:deck) { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck) }

  describe "GET /api/v1/decks/:id/stats" do
    it "devuelve stats vacías sin tarjetas" do
      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["total_cards"]).to eq(0)
      expect(body["due_today"]).to eq(0)
      expect(body["mastered"]).to eq(0)
      expect(body["progress"]).to eq(0)
      expect(body["success_rate"]).to be_nil
    end

    it "cuenta tarjetas pendientes correctamente" do
      create(:card, category: category)
      create(:card, category: category)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["total_cards"]).to eq(2)
      expect(body["due_today"]).to eq(2)
    end

    it "calcula success_rate al 100% con solo aciertos" do
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )
      review.apply_review!(5)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["success_rate"]).to eq(100.0)
    end

    it "no cuenta quality 3 como éxito" do
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )
      review.apply_review!(3)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["success_rate"]).to eq(0.0)
    end

    it "calcula success_rate al 0% con solo fallos" do
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )
      review.apply_review!(1)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["success_rate"]).to eq(0.0)
    end

    it "calcula success_rate mixto correctamente" do
      card1 = create(:card, category: category, front: "Q1", back: "A1")
      card2 = create(:card, category: category, front: "Q2", back: "A2")

      review1 = CardReview.create!(
        card: card1, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )
      review2 = CardReview.create!(
        card: card2, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )

      review1.apply_review!(5)  # éxito
      review2.apply_review!(1)  # fallo

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["success_rate"]).to eq(50.0)
    end

    it "cuenta tarjetas dominadas con intervalo mayor a 21" do
      card = create(:card, category: category)
      CardReview.create!(
        card: card, user: user,
        repetitions: 5, interval: 30, easiness: 2.5,
        next_review_at: 30.days.from_now
      )

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["mastered"]).to eq(1)
      expect(body["progress"]).to eq(100.0)
    end

    it "no mezcla stats de otros usuarios" do
      otro = create(:user, email: "otro@test.com")
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: otro,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )
      review.apply_review!(5)

      get "/api/v1/decks/#{deck.id}/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["success_rate"]).to be_nil
    end
  end
end