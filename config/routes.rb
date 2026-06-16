Rails.application.routes.draw do
  devise_for :tribes, controllers: {
    sessions: "tribes/sessions",
    registrations: "tribes/registrations"
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "regions", to: "regions#index"

  get "tribes/:username", to: "public_profiles#show",
                          constraints: { username: /[a-z0-9_]+/ },
                          as: :public_profile

  get "share/:token", to: "share_profiles#show",
                      constraints: { token: /[A-Za-z0-9_-]{20,48}/ },
                      as: :share_profile

  namespace :me do
    resource :profile, only: %i[show update], controller: "profiles" do
      post :publish
    end

    resource :share_link, only: %i[show], controller: "share_links" do
      post :rotate
    end

    resources :tips, only: %i[index show] do
      member do
        post :reconcile
      end
    end

    resources :notifications, only: %i[index] do
      member do
        patch :read
      end
      collection do
        patch :read_all, action: :read_all
      end
    end

    namespace :paystack do
      resource :onboarding, only: %i[show create], controller: "onboarding"
      resources :settlements, only: %i[index show]
      resources :withdrawals, only: %i[index create]
      resource :repair, only: %i[create], controller: "repairs"
    end
  end

  post "tips", to: "tips#create"
  get "tips/checkout/:paystack_reference", to: "tips#checkout", as: :tip_checkout
  post "tips/:paystack_reference/reconcile", to: "tips#reconcile", as: :tip_reconcile
  post "paystack/webhook", to: "paystack/webhooks#create"

  namespace :admin do
    get "tribes", to: "tribes#index"
    patch "tribes/:id/suspend", to: "tribes#suspend"
    patch "tribes/:id/activate", to: "tribes#activate"
    get "tribes/:id/paystack_audit", to: "paystack/audits#show"
    get "tribes/:id/settlements", to: "settlements#index"
    post "tribes/:id/repair", to: "repairs#create"
    get "paystack_events", to: "paystack_events#index"
    post "paystack_events/:id/replay", to: "paystack_events#replay"
    get "tips/:paystack_reference/investigate", to: "tips#investigate"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
