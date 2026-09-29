Rails.application.routes.draw do
  get "home/index"
  root "home#index"
  
  get "clinics", to: "clinics#public_index"
  
  resource :session, only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  namespace :dashboard do
    get "/", to: "overview#index"
    resources :clinics
    resources :patients
    resources :appointments, only: [:index, :create, :update]
    resources :reports, only: [:index, :create]
    resources :medications, only: [:index, :create]
    resources :transfers, only: [:index, :create, :update]
    resources :payments, only: [:index, :create]
    resources :subscriptions, only: [:index]
    resources :chat, only: [:index, :create]
  end

  patch "set_locale", to: "application#set_locale"
end
