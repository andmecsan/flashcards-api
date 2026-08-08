Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "/auth/google_oauth2/callback", to: "auth#google_callback"
  get  "/auth/failure",                to: "auth#failure"

  namespace :api do
    namespace :v1 do
      resources :decks do
        resources :cards, shallow: true
        get  :study,  on: :member
        post :import, on: :member
      end

      resources :cards, only: [] do
        post :review, on: :member
      end
    end
  end
end