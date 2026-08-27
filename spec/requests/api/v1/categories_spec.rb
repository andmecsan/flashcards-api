require "rails_helper"

RSpec.describe "Api::V1::Categories", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:deck) { create(:deck, user: user) }

  describe "GET /api/v1/decks/:id/categories" do
    it "lista las categorías del mazo" do
      create(:category, deck: deck, name: "Verbos")
      create(:category, deck: deck, name: "Sustantivos")

      get "/api/v1/decks/#{deck.id}/categories", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "POST /api/v1/decks/:id/categories" do
    it "crea una categoría" do
      params = { category: { name: "Vocabulario" } }

      post "/api/v1/decks/#{deck.id}/categories", params: params, headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["name"]).to eq("Vocabulario")
    end

    it "no permite nombres duplicados en el mismo mazo" do
      create(:category, deck: deck, name: "Duplicada")
      params = { category: { name: "Duplicada" } }

      post "/api/v1/decks/#{deck.id}/categories", params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/categories/:id" do
    it "elimina la categoría" do
      category = create(:category, deck: deck)

      delete "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Category.exists?(category.id)).to be false
    end

    it "no permite eliminar categorías de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro, name: "Otro mazo")
      category = create(:category, deck: otro_deck)

      delete "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
