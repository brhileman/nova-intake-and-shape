# frozen_string_literal: true

# Creates a batch of requests from a decomposition plan
# Creates a request group and all associated requests with pre-drafted plans
class RequestBatchCreator
  attr_reader :decomposition_plan, :request_group, :created_requests, :errors

  def initialize(decomposition_plan)
    @decomposition_plan = decomposition_plan
    @project = decomposition_plan.project
    @created_requests = []
    @errors = []
  end

  # Create all requests from the decomposition plan
  # @param selected_indices [Array<Integer>] Optional array of request indices to create (1-based)
  #   If nil, creates all requests
  # @return [Boolean] true if all requests were created successfully
  def create_all(selected_indices: nil)
    return false unless decomposition_plan.ready_for_approval?

    # Parse the plan content
    extractor = DecompositionPlanExtractor.new(decomposition_plan.plan_content)
    extracted = extractor.extract
    requests_data = extracted[:requests]

    return add_error("No requests found in plan") if requests_data.empty?

    # Filter to selected indices if specified
    if selected_indices.present?
      requests_data = requests_data.select { |r| selected_indices.include?(r[:number]) }
    end

    return add_error("No requests selected") if requests_data.empty?

    ActiveRecord::Base.transaction do
      # 1. Create the request group
      @request_group = create_request_group(extracted[:title])
      raise ActiveRecord::Rollback unless @request_group.persisted?

      # 2. Get the current max position for the project
      base_position = @project.requests.maximum(:position) || 0

      # 3. Create each request with its plan
      requests_data.each_with_index do |request_data, index|
        request = create_request_with_plan(request_data, base_position + index + 1)

        if request&.persisted?
          @created_requests << request
        else
          @errors << "Failed to create request: #{request_data[:title]}"
          raise ActiveRecord::Rollback
        end
      end

      # 4. Update decomposition plan status
      decomposition_plan.update!(status: "approved")
    end

    @errors.empty?
  end

  private

  def create_request_group(plan_title)
    group_name = plan_title.presence || "Plan #{decomposition_plan.id}"

    # Ensure unique name within project
    base_name = group_name
    counter = 1
    while @project.request_groups.exists?(name: group_name)
      group_name = "#{base_name} (#{counter})"
      counter += 1
    end

    @project.request_groups.create!(
      name: group_name,
      description: decomposition_plan.original_input.truncate(500),
      created_by: decomposition_plan.created_by,
      decomposition_plan: decomposition_plan
    )
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to create group: #{e.message}"
    nil
  end

  def create_request_with_plan(request_data, position)
    # Build the original_input from the request data
    original_input = build_original_input(request_data)

    # Determine request type
    request_type = case request_data[:type]
    when "new", "new_feature" then :new_feature
    when "update" then :update
    when "fix" then :fix
    when "chore" then :chore
    else :new_feature
    end

    # Determine priority
    priority = case request_data[:priority]&.downcase
    when "high" then :high
    when "low" then :low
    else :medium
    end

    # Create the request (skipping intake phase - starts at plan_ready)
    request = @project.requests.create!(
      original_input: original_input,
      status: "plan_ready",
      request_type: request_type,
      request_group: @request_group,
      created_by: decomposition_plan.created_by,
      position: position,
      priority: priority,
      dependencies: request_data[:dependencies],
      # Pre-populate extracted fields
      generated_title: request_data[:title],
      user_story_persona: request_data[:persona],
      user_story_action: request_data[:action],
      user_story_outcome: request_data[:outcome]
    )

    # Create the plan
    plan_content = build_plan_content(request_data)
    request.plans.create!(
      content: plan_content,
      created_by: decomposition_plan.created_by
    )

    request
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to create request '#{request_data[:title]}': #{e.message}"
    nil
  end

  def build_original_input(request_data)
    parts = []
    parts << request_data[:title] if request_data[:title].present?

    if request_data[:persona].present? && request_data[:action].present?
      parts << "As a #{request_data[:persona]}, I want #{request_data[:action]}"
      parts << "so that #{request_data[:outcome]}" if request_data[:outcome].present?
    end

    parts.join(". ")
  end

  def build_plan_content(request_data)
    type = request_data[:type] || "new"

    <<~PLAN
      ## Implementation Plan

      **Title:** #{request_data[:title]}

      **Type:** #{type}

      **As a** #{request_data[:persona]}
      **I want** #{request_data[:action]}
      **So that** #{request_data[:outcome]}

      ## Scenarios

      ### Happy Path
      1. [To be detailed during planning]

      ## Technical Implementation

      [To be detailed during planning]

      ## Acceptance Criteria
      - [ ] [To be detailed during planning]

      ---
      STATUS: clarified
    PLAN
  end

  def add_error(message)
    @errors << message
    false
  end
end
