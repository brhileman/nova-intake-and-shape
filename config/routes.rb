Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Nova Flow UI routes
  root "requests#index"

  # Project switching
  resources :projects, only: [] do
    member do
      post :select
    end
  end

  resources :requests, only: [ :index, :show, :new, :create ] do
    member do
      get :poll       # Polling endpoint - checks agent status, auto-transitions, returns Turbo Stream
      post :comment   # Send message to agent (calls agent.followup)
      post :approve   # Approve current phase, triggers state transition + launches next agent
    end
  end
end
