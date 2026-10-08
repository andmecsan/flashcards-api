require "rails_helper"

RSpec.describe "GET /api/v1/stats/mastery", type: :request do
  let(:user) { create(:user) }

  it "devuelve el ranking del usuario autenticado" do
    card = create(:card, category: create(:category, deck: create(:deck, user: user), name: "Difícil"))
    review = CardReview.create!(card: card, user: user, repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current)
    5.times { review.apply_review!(1) }

    get "/api/v1/stats/mastery", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["weak"].map { |e| e["name"] }).to eq([ "Difícil" ])
    expect(body["strong"]).to eq([])
    expect(body["total_reviews"]).to eq(5)
  end

  it "no expone datos de otro usuario" do
    otro = create(:user, email: "otro@test.com")
    card = create(:card, category: create(:category, deck: create(:deck, user: otro)))
    review = CardReview.create!(card: card, user: otro, repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current)
    5.times { review.apply_review!(1) }

    get "/api/v1/stats/mastery", headers: auth_headers(user)

    expect(JSON.parse(response.body)).to include("weak" => [], "strong" => [], "total_reviews" => 0)
  end

  it "devuelve 401 sin token" do
    get "/api/v1/stats/mastery"

    expect(response).to have_http_status(:unauthorized)
  end

  describe "?group=" do
    it "agrupa por etiqueta personal con group=tag" do
      card = create(:card, category: create(:category, deck: create(:deck, user: user), name: "Tema"))
      card.replace_personal_tags!([ "Fórmulas" ])
      review = CardReview.create!(card: card, user: user, repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current)
      5.times { review.apply_review!(1) }

      get "/api/v1/stats/mastery", params: { group: "tag" }, headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["weak"].map { |e| e["name"] }).to eq([ "Fórmulas" ])
    end

    it "responde 400 con una agrupación no válida" do
      get "/api/v1/stats/mastery", params: { group: "deck" }, headers: auth_headers(user)

      expect(response).to have_http_status(:bad_request)
    end
  end
end
