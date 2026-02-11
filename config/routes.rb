Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Nova Flow UI routes
  root "home#index"

  # Projects - show for project-specific home, select for switching
  resources :projects, only: [:show] do
    member do
      post :select
      get :context      # Show context editor
      post :context     # Save context
    end

    # Request groups for organizing requests
    resources :request_groups, only: [:create, :destroy]

    # Decomposition plans for breaking down initiatives into requests
    resources :decomposition_plans, only: [:new, :create, :show] do
      collection do
        get :new_plan  # Shows the actual new plan form
      end
      member do
        post :followup
        get :poll
        post :approve
        post :cancel
      end
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

  resources :requests, only: [ :index, :show, :new, :create ] do
    collection do
      patch :reorder    # Bulk update positions for drag-and-drop
    end

    member do
      get :poll                  # Polling endpoint - checks agent status, returns Turbo Stream
      post :comment              # Send message to agent (calls agent.followup)
      post :build                # Start execution - launches execution agent
      patch :update_plan         # Auto-save plan content
      post :team_comment         # Add team comment (internal discussion)
      patch :update_group        # Update request's group assignment
      patch :update_priority     # Update request's priority
      patch :update_dependencies # Update request's dependencies
    end

    # Nested singular resources for guidance (one per request)
    resource :design_guidance, only: [ :create, :update ]
    resource :technical_guidance, only: [ :create, :update ]
  end
end
