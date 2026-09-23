Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :tickets, only: [ :new, :create, :show, :update ]

  namespace :admin do
    resources :services
    resources :topics
    resources :users, only: [ :index, :show, :update ]
  end

  post "/mcp", to: "mcp#create", as: :mcp
  match "/mcp", to: "mcp#unsupported", via: [ :get, :delete ]

  resource :settings, only: [ :show ] do
    post :api_token
    delete :api_token, action: :revoke_api_token
  end

  namespace :slack do
    post "interactions", to: "interactions#create"
    post "events", to: "events#create"
  end

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/logout", to: "sessions#destroy"
end
