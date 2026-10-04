
Rails.application.routes.draw do
  root "home#index"

  resource  :session,       only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  post "/switch_clinic", to: "clinics#switch", as: :switch_clinic
  post "/switch_locale", to: "locales#update", as: :switch_locale

  get   "/profile",           to: "profile#show",            as: :profile
  get   "/profile/edit",      to: "profile#edit",            as: :edit_profile
  patch "/profile",           to: "profile#update"
  patch "/profile/password",  to: "profile#update_password", as: :update_profile_password

  resources :notifications, only: [:index, :destroy] do
    member do
      post :mark_read
    end
    collection do
      post :mark_all_read
    end
  end

  namespace :dashboard do
    root to: "overview#index"

    resources :clinics, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        post :add_member
        delete "remove_member/:member_id", to: "clinics#remove_member", as: :remove_member
      end
      resources :clinic_invitations, only: [:create, :destroy], controller: "clinic_invitations" do
        member do
          post :resend
        end
      end
    end

    resources :patients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        get :timeline
        get :qr
      end
      resources :medical_images, only: [:index, :create, :show, :destroy], controller: "medical_images"
    end

    # Calendar view for appointments
    get "calendar",            to: "calendars#index", as: :calendar
    get "calendar/day/:date",  to: "calendars#day",   as: :day_dashboard_calendar

     resources :appointments, only: [:index, :show, :new, :create, :destroy] do
      member do
        post  :accept_booking
        post  :reject_booking
        get   :ics
        get   :wizard
        post  :wizard_save
        patch :check_in
        patch :start_visit
        patch :complete
        patch :cancel
        patch :no_show
        get   :prescription
        post  :send_reminder
      end
    end

    resources :reports,       only: [:index, :show, :create, :destroy]
    resources :medications, only: [:index, :show, :create, :destroy] do
      member do
        patch :discontinue
        patch :complete
        patch :refill
      end
    end
    resources :transfers,     only: [:index, :create, :destroy]
    resources :payments, only: [:index, :show, :create, :destroy] do
      member do
        patch :refund
        patch :mark_paid
        patch :mark_pending
        get   :receipt
      end
    end
      resources :subscriptions, only: [:index] do
      collection do
        post :upgrade
        get  :checkout
        post :submit_payment
      end
    end

    get  "chat", to: "chat#index", as: :chat
    post "chat", to: "chat#create"
  end

  # Public prescription view (no login) — scanned from QR code
  get "/p/:token", to: "public_prescriptions#show", as: :public_prescription

  get "/dashboard", to: "dashboard/overview#index", as: :dashboard
  get "/qr", to: "qr_codes#show", as: :qr_code

  get "/m/:token", to: "public_medications#show", as: :public_medication

  # Public clinic page (from directory)
  get "/c/:slug", to: "public_clinics#show", as: :public_clinic

  # Public booking (patient-facing)
  get  "/c/:slug/book",         to: "public_bookings#new",     as: :new_public_booking
  post "/c/:slug/book",         to: "public_bookings#create",  as: :public_bookings
  get  "/c/:slug/book/success", to: "public_bookings#success", as: :public_booking_success
  get  "/c/:slug/book/status",  to: "public_bookings#status",  as: :public_booking_status


  # Letter opener web UI (dev only)


  namespace :admin do
    root to: "dashboard#index"

    resources :users, only: [:index, :show] do
      member do
        post  :impersonate
        patch :deactivate
        patch :activate
        patch :reset_password
      end
    end

    resources :clinics, only: [:index, :show] do
      member do
        patch :toggle_public
        patch :deactivate
        patch :activate
      end
    end

    resources :subscriptions, only: [:index, :show, :update] do
      member do
        patch :confirm_payment
        patch :reject_payment
      end
    end
  end
end
