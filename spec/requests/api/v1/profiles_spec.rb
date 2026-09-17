require "rails_helper"

RSpec.describe "Api::V1::Profiles", type: :request do
  let(:user) { User.create!(name: "Andrea", email: "andrea@test.com", password: "secreto1") }
  let(:headers) { auth_headers(user) }

  describe "PATCH /api/v1/profile" do
    it "no permite cambiar la contraseña sin enviar la contraseña actual" do
      patch "/api/v1/profile", params: { password: "nueva123" }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate("nueva123")).to be false
      expect(user.authenticate("secreto1")).to be_truthy
    end

    it "no permite cambiar la contraseña con la contraseña actual incorrecta" do
      patch "/api/v1/profile", params: { current_password: "incorrecta", password: "nueva123" }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate("nueva123")).to be false
    end

    it "permite cambiar la contraseña enviando la contraseña actual correcta" do
      patch "/api/v1/profile", params: { current_password: "secreto1", password: "nueva123" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate("nueva123")).to be_truthy
    end

    it "permite añadir una contraseña sin contraseña actual si el usuario aún no tiene una (solo Google)" do
      google_user = User.create!(name: "Google User", email: "google@test.com", uid: "google-123")
      google_headers = auth_headers(google_user)

      patch "/api/v1/profile", params: { password: "nueva123" }, headers: google_headers

      expect(response).to have_http_status(:ok)
      expect(google_user.reload.authenticate("nueva123")).to be_truthy
    end

    it "permite cambiar el nombre sin exigir la contraseña actual" do
      patch "/api/v1/profile", params: { name: "Nuevo nombre" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.name).to eq("Nuevo nombre")
    end
  end
end
