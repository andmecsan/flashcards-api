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
      expect(body["in_progress"]).to eq(0)
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
      expect(body["in_progress"]).to eq(0)
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

    describe "weak_cards (nube de repaso)" do
      def review_for(card, owner = user, interval: 1)
        CardReview.create!(
          card: card, user: owner,
          repetitions: 0, interval: interval, easiness: 2.5,
          next_review_at: Time.current
        )
      end

      it "devuelve una lista vacía sin repasos" do
        create(:card, category: category)

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        expect(JSON.parse(response.body)["weak_cards"]).to eq([])
      end

      it "pondera 2 por cada fallo y 1 por cada 'más o menos'" do
        dificil = create(:card, category: category, front: "Difícil", back: "A")
        dudosa  = create(:card, category: category, front: "Dudosa", back: "B")
        r1 = review_for(dificil)
        r1.apply_review!(1)
        r1.apply_review!(1)
        review_for(dudosa).apply_review!(3)

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        weak = JSON.parse(response.body)["weak_cards"]
        expect(weak.map { |c| [ c["front"], c["weight"] ] }).to eq([ [ "Difícil", 4 ], [ "Dudosa", 1 ] ])
      end

      it "no incluye las tarjetas que solo se han acertado" do
        review_for(create(:card, category: category)).apply_review!(5)

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        expect(JSON.parse(response.body)["weak_cards"]).to eq([])
      end

      it "no incluye las tarjetas ya dominadas" do
        card = create(:card, category: category)
        review = review_for(card)
        review.apply_review!(1)
        review.update!(interval: 30)

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        expect(JSON.parse(response.body)["weak_cards"]).to eq([])
      end

      it "no mezcla los fallos de otros usuarios" do
        otro = create(:user, email: "otro@test.com")
        review_for(create(:card, category: category), otro).apply_review!(1)

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        expect(JSON.parse(response.body)["weak_cards"]).to eq([])
      end

      it "limita el resultado a las 20 más difíciles" do
        25.times do |i|
          review_for(create(:card, category: category, front: "Q#{i}", back: "A")).apply_review!(1)
        end

        get "/api/v1/decks/#{deck.id}/stats", headers: headers

        expect(JSON.parse(response.body)["weak_cards"].size).to eq(20)
      end
    end
  end
end
