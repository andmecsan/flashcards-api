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

  describe "GET /api/v1/categories/:id" do
    it "muestra un temario propio" do
      category = create(:category, deck: deck, name: "Verbos")

      get "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Verbos")
    end

    it "no permite ver un temario de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro)
      category = create(:category, deck: otro_deck)

      get "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/categories/:id" do
    it "actualiza un temario" do
      category = create(:category, deck: deck, name: "Nombre viejo")

      patch "/api/v1/categories/#{category.id}", params: { category: { name: "Nombre nuevo" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Nombre nuevo")
    end

    it "no permite actualizar un temario de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro)
      category = create(:category, deck: otro_deck, name: "Original")

      patch "/api/v1/categories/#{category.id}", params: { category: { name: "Hackeado" } }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(category.reload.name).to eq("Original")
    end
  end

  describe "GET /api/v1/categories/:id/review_cards" do
    it "devuelve las tarjetas de un temario propio en modo repaso libre" do
      category = create(:category, deck: deck)
      create(:card, category: category)

      get "/api/v1/categories/#{category.id}/review_cards", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "no permite repasar un temario de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro)
      category = create(:category, deck: otro_deck)

      get "/api/v1/categories/#{category.id}/review_cards", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/categories/:id/update_topic" do
    it "reemplaza el nombre y las tarjetas de un temario propio" do
      category = create(:category, deck: deck, name: "Nombre viejo")
      create(:card, category: category, front: "Vieja")
      params = { name: "Nombre nuevo", cards: [ { front: "Nueva", back: "Respuesta" } ] }

      patch "/api/v1/categories/#{category.id}/update_topic", params: params, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["category"]["name"]).to eq("Nombre nuevo")
      expect(body["cards"].size).to eq(1)
      expect(body["cards"].first["front"]).to eq("Nueva")
    end

    it "no permite editar en bloque un temario de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro)
      category = create(:category, deck: otro_deck, name: "Original")
      params = { name: "Hackeado", cards: [] }

      patch "/api/v1/categories/#{category.id}/update_topic", params: params, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(category.reload.name).to eq("Original")
    end

    describe "conservación del progreso" do
      def study(card)
        CardReview.create!(
          card: card, user: user,
          repetitions: 0, interval: 1, easiness: 2.5, next_review_at: Time.current
        ).tap { |r| r.apply_review!(5) }
      end

      let(:category) { create(:category, deck: deck, name: "Tema") }

      it "actualiza en el sitio las tarjetas que llegan con id y conserva su progreso" do
        card = create(:card, category: category, front: "Vieja", back: "R")
        review = study(card)

        patch "/api/v1/categories/#{category.id}/update_topic",
              params: { name: "Tema", cards: [ { id: card.id, front: "Corregida", back: "R" } ] },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(card.reload.front).to eq("Corregida")
        expect(CardReview.exists?(review.id)).to be(true)
        expect(review.review_logs.count).to eq(1)
      end

      it "crea las tarjetas sin id y borra las que ya no aparecen" do
        keep = create(:card, category: category, front: "Se queda", back: "R")
        gone = create(:card, category: category, front: "Se va", back: "R")
        gone_review = study(gone)

        patch "/api/v1/categories/#{category.id}/update_topic",
              params: { name: "Tema", cards: [ { id: keep.id, front: "Se queda", back: "R" }, { front: "Nueva", back: "R" } ] },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(category.cards.pluck(:front)).to contain_exactly("Se queda", "Nueva")
        expect(CardReview.exists?(gone_review.id)).to be(false)
      end

      it "no toca tarjetas de otro temario aunque lleguen con su id" do
        otro_deck = create(:deck, user: create(:user, email: "otro@test.com"))
        ajena = create(:card, category: create(:category, deck: otro_deck), front: "Ajena", back: "R")

        patch "/api/v1/categories/#{category.id}/update_topic",
              params: { name: "Tema", cards: [ { id: ajena.id, front: "Robada", back: "R" } ] },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(ajena.reload.front).to eq("Ajena")
        expect(ajena.category_id).not_to eq(category.id)
        expect(category.cards.pluck(:front)).to eq([ "Robada" ])
      end

      it "no deja cambios a medias si una tarjeta es inválida" do
        card = create(:card, category: category, front: "Original", back: "R")

        patch "/api/v1/categories/#{category.id}/update_topic",
              params: { name: "Cambiado", cards: [ { id: card.id, front: "Cambio", back: "R" }, { front: "", back: "R" } ] },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(category.reload.name).to eq("Tema")
        expect(card.reload.front).to eq("Original")
      end
    end
  end
end
