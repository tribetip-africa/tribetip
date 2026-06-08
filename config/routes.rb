Rails.application.routes.draw do
  devise_for :tribes, controllers: {
    sessions: "tribes/sessions",
    registrations: "tribes/registrations"
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "tribes/:username", to: "public_profiles#show",
                          constraints: { username: /[a-z0-9_]+/ },
                          as: :public_profile

  namespace :me do
    resource :profile, only: %i[show update], controller: "profiles" do
      post :publish
    end

    resources :tips, only: %i[index show]

    namespace :paystack do
      resource :onboarding, only: %i[show create], controller: "onboarding"
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
    get "paystack_events", to: "paystack_events#index"
    post "paystack_events/:id/replay", to: "paystack_events#replay"
    get "tips/:paystack_reference/investigate", to: "tips#investigate"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
