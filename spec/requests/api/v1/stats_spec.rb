require "rails_helper"

RSpec.describe "Api::V1::Stats", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:deck) { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck) }

  describe "GET /api/v1/stats" do
    it "devuelve stats vacías sin actividad" do
      get "/api/v1/stats", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["study_streak"]).to eq(0)
      expect(body["last_session"]).to be_nil
      expect(body["next_review"]).to be_nil
    end

    it "detecta tarjetas pendientes en next_review" do
      card = create(:card, category: category)

      get "/api/v1/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["next_review"]).not_to be_nil
      expect(body["next_review"]["due_count"]).to eq(1)
      expect(body["next_review"]["category_name"]).to eq(category.name)
    end

    it "calcula la racha de estudio correctamente" do
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )

      # Estudiar hoy
      review.apply_review!(4)

      get "/api/v1/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["study_streak"]).to eq(1)
    end

    it "calcula la última sesión correctamente" do
      card = create(:card, category: category)
      review = CardReview.create!(
        card: card, user: user,
        repetitions: 0, interval: 1, easiness: 2.5,
        next_review_at: Time.current
      )

      review.apply_review!(5)

      get "/api/v1/stats", headers: headers

      body = JSON.parse(response.body)
      expect(body["last_session"]).not_to be_nil
      expect(body["last_session"]["cards_count"]).to eq(1)
      expect(body["last_session"]["success_rate"]).to eq(100.0)
    end
  end
end