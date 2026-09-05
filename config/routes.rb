Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "/auth/google_oauth2/callback", to: "auth#google_callback"
  get  "/auth/failure",                to: "auth#failure"
  post "/auth/register", to: "auth#register"
  post "/auth/login",    to: "auth#login"

  namespace :api do
    namespace :v1 do
      resource :profile, only: [:show, :update, :destroy]
      resources :stats, only: [:index]
      resources :decks do
        get :study, on: :member
        get :stats, on: :member
        post :create_topic, on: :member  # añade esta línea
        resources :categories, shallow: true do
          resources :cards, shallow: true
          patch :update_topic, on: :member
          get :review_cards, on: :member
        end
      end

      resources :cards, only: [] do
        post :review, on: :member
        post :generate, on: :collection
      end
    end
  end
end
