require "rails_helper"

RSpec.describe "Api::V1::Cards", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:deck) { create(:deck, user: user) }
  let(:category) { create(:category, deck: deck) }

  describe "POST /api/v1/categories/:id/cards" do
    it "crea una tarjeta" do
      params = { card: { front: "¿Qué es Ruby?", back: "Un lenguaje de programación" } }

      post "/api/v1/categories/#{category.id}/cards", params: params, headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["front"]).to eq("¿Qué es Ruby?")
    end
  end

  describe "GET /api/v1/categories/:id/cards" do
    it "lista las tarjetas de la categoría" do
      create(:card, category: category, front: "Pregunta 1")
      create(:card, category: category, front: "Pregunta 2")

      get "/api/v1/categories/#{category.id}/cards", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "POST /api/v1/cards/:id/review" do
    it "aplica SM-2 y devuelve el nuevo estado" do
      card = create(:card, category: category)

      post "/api/v1/cards/#{card.id}/review",
        params: { quality: 5 },
        headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["repetitions"]).to eq(1)
      expect(body["interval"]).to eq(1)
    end

    it "rechaza quality inválido" do
      card = create(:card, category: category)

      post "/api/v1/cards/#{card.id}/review",
        params: { quality: 7 },
        headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
