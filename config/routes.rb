Rails.application.routes.draw do
  resources :chats, only: :create
  root "welcome#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
