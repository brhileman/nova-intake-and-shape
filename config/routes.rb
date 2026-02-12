Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Nova Flow Intake & Shape UI routes
  root "home#index"

  # Projects - show for project-specific home, select for switching
  resources :projects, only: [:show] do
    member do
      post :select
      get :context         # Show context editor
      post :context        # Save context
      get :asana_settings  # Show Asana integration settings
      post :asana_settings # Save Asana integration settings
    end
  end

  # User switching (for role-based testing)
  resources :users, only: [] do
    member do
      post :select
    end
  end

  # Ephemeral intake endpoints (no Request record created yet)
  scope :intake, controller: "intake" do
    post :start, as: :intake_start       # Creates ephemeral agent, returns agent_id
    post :message, as: :intake_message   # Sends message to ephemeral agent
    get :poll, as: :intake_poll          # Checks agent status, extracts plan when ready
  end

  # Shaped tasks (intake history)
  resources :requests, only: [ :index, :show, :new, :create ]
end
