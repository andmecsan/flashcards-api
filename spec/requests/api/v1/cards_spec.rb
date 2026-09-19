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

    it "no permite calificar una tarjeta de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_deck = create(:deck, user: otro)
      otro_category = create(:category, deck: otro_deck)
      card = create(:card, category: otro_category)

      post "/api/v1/cards/#{card.id}/review",
        params: { quality: 5 },
        headers: headers

      expect(response).to have_http_status(:not_found)
      expect(CardReview.where(card: card)).to be_empty
    end
  end

  describe "GET /api/v1/cards/:id" do
    it "muestra una tarjeta propia" do
      card = create(:card, category: category, front: "¿Qué es Ruby?")

      get "/api/v1/cards/#{card.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["front"]).to eq("¿Qué es Ruby?")
    end

    it "no permite ver una tarjeta de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_category = create(:category, deck: create(:deck, user: otro))
      card = create(:card, category: otro_category)

      get "/api/v1/cards/#{card.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/cards/:id" do
    it "actualiza una tarjeta" do
      card = create(:card, category: category, front: "Pregunta vieja")

      patch "/api/v1/cards/#{card.id}", params: { card: { front: "Pregunta nueva" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["front"]).to eq("Pregunta nueva")
    end

    it "no permite actualizar una tarjeta de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_category = create(:category, deck: create(:deck, user: otro))
      card = create(:card, category: otro_category, front: "Original")

      patch "/api/v1/cards/#{card.id}", params: { card: { front: "Hackeada" } }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(card.reload.front).to eq("Original")
    end
  end

  describe "DELETE /api/v1/cards/:id" do
    it "elimina una tarjeta propia" do
      card = create(:card, category: category)

      delete "/api/v1/cards/#{card.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Card.exists?(card.id)).to be false
    end

    it "no permite eliminar una tarjeta de otro usuario" do
      otro = create(:user, email: "otro@test.com")
      otro_category = create(:category, deck: create(:deck, user: otro))
      card = create(:card, category: otro_category)

      delete "/api/v1/cards/#{card.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(Card.exists?(card.id)).to be true
    end
  end

  describe "POST /api/v1/cards/generate" do
    let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/dummy.pdf"), "application/pdf") }

    it "genera una propuesta de tarjetas a partir de un PDF" do
      allow_any_instance_of(PdfExtractorService).to receive(:extract_text).and_return("Contenido de ejemplo")
      allow_any_instance_of(GeminiService).to receive(:generate_cards).and_return(
        { "name" => "Tema generado", "cards" => [ { "front" => "P1", "back" => "R1" } ] }
      )

      post "/api/v1/cards/generate", params: { file: file }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Tema generado")
      expect(body["cards"].size).to eq(1)
    end

    it "no persiste nada en base de datos, solo devuelve la propuesta" do
      allow_any_instance_of(PdfExtractorService).to receive(:extract_text).and_return("Contenido de ejemplo")
      allow_any_instance_of(GeminiService).to receive(:generate_cards).and_return(
        { "name" => "Tema generado", "cards" => [ { "front" => "P1", "back" => "R1" } ] }
      )

      expect {
        post "/api/v1/cards/generate", params: { file: file }, headers: headers
      }.not_to change(Card, :count)
    end

    it "rechaza la petición si no se sube ningún archivo" do
      post "/api/v1/cards/generate", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "devuelve error si no se puede extraer texto del PDF" do
      allow_any_instance_of(PdfExtractorService).to receive(:extract_text).and_return("")

      post "/api/v1/cards/generate", params: { file: file }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "devuelve 429 si se ha alcanzado el límite de peticiones a Gemini" do
      allow_any_instance_of(PdfExtractorService).to receive(:extract_text).and_return("Contenido de ejemplo")
      allow_any_instance_of(GeminiService).to receive(:generate_cards).and_raise(GeminiService::RateLimitError)

      post "/api/v1/cards/generate", params: { file: file }, headers: headers

      expect(response).to have_http_status(:too_many_requests)
    end

    it "devuelve 503 si el servicio de Gemini no está disponible" do
      allow_any_instance_of(PdfExtractorService).to receive(:extract_text).and_return("Contenido de ejemplo")
      allow_any_instance_of(GeminiService).to receive(:generate_cards).and_raise(GeminiService::UnavailableError)

      post "/api/v1/cards/generate", params: { file: file }, headers: headers

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
