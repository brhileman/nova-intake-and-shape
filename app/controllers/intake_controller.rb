# frozen_string_literal: true

class IntakeController < ApplicationController
  before_action :require_project

  # POST /intake/start
  # Creates ephemeral agent, stores agent_id in session, returns JSON with agent_id
  def start
    original_input = params[:original_input]

    if original_input.blank?
      render json: { success: false, error: "Please describe your request." }, status: :unprocessable_entity
      return
    end

    begin
      agent = Agents::EphemeralIntakeAgent.new(
        project: current_project,
        original_input: original_input
      )
      agent.launch

      # Store in session for subsequent requests
      session[:intake_agent_id] = agent.agent_id
      session[:intake_original_input] = original_input

      render json: {
        success: true,
        agent_id: agent.agent_id
      }
    rescue Agents::EphemeralIntakeAgent::ProjectNotConfiguredError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "[Intake] Failed to launch agent: #{e.message}"
      render json: { success: false, error: "Failed to start intake process. Please try again." }, status: :internal_server_error
    end
  end

  # POST /intake/message
  # Sends message to ephemeral agent
  def message
    agent_id = session[:intake_agent_id]
    message_text = params[:message]

    unless agent_id
      render json: { success: false, error: "No active intake session." }, status: :unprocessable_entity
      return
    end

    if message_text.blank?
      render json: { success: false, error: "Message cannot be empty." }, status: :unprocessable_entity
      return
    end

    begin
      client = CursorApi::Client.new
      client.followup(agent_id, prompt: message_text)

      render json: { success: true }
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[Intake] Failed to send message: #{e.message}"
      render json: { success: false, error: "Failed to send message." }, status: :internal_server_error
    end
  end

  # GET /intake/poll
  # Checks agent status, returns status and conversation
  def poll
    agent_id = session[:intake_agent_id]

    unless agent_id
      render json: { success: false, error: "No active intake session." }, status: :unprocessable_entity
      return
    end

    begin
      client = CursorApi::Client.new
      agent_status = client.get_agent(agent_id)
      conversation = client.get_conversation(agent_id)

      status_str = agent_status["status"]&.to_s&.upcase
      messages = conversation["messages"] || []

      # Determine the intake status based on agent status and content
      intake_status = determine_intake_status(status_str, messages)

      response = {
        success: true,
        status: intake_status,
        messages: format_messages(messages)
      }

      # If plan is ready, include the plan content
      if intake_status == "plan_ready"
        plan_content = extract_plan_content(messages)
        response[:plan_content] = plan_content
      end

      render json: response
    rescue CursorApi::Client::Error => e
      Rails.logger.error "[Intake] Failed to poll agent: #{e.message}"
      render json: { success: false, error: "Failed to check status." }, status: :internal_server_error
    end
  end

  private

  def require_project
    unless current_project
      render json: { success: false, error: "No project selected." }, status: :unprocessable_entity
    end
  end

  def determine_intake_status(agent_status, messages)
    return "processing" unless agent_status == "FINISHED"

    # Check the last assistant message for status markers
    last_assistant_msg = messages.reverse.find { |m| m["type"] == "assistant_message" }
    return "processing" unless last_assistant_msg

    content = last_assistant_msg["text"] || ""

    # Check for clarification markers
    if content.include?("[STATUS: NEEDS_CLARIFICATION]") ||
       content.include?("could you clarify") ||
       content.include?("I need more information") ||
       content.include?("Can you tell me more")
      return "needs_clarification"
    end

    # Check for plan markers
    if content.include?("[STATUS: PLAN_READY]") ||
       content.include?("## Plan") ||
       content.include?("## Implementation Plan") ||
       content.include?("### Tasks") ||
       content.include?("## Summary")
      return "plan_ready"
    end

    # Default to needs_clarification if finished but unclear
    "needs_clarification"
  end

  def extract_plan_content(messages)
    last_assistant_msg = messages.reverse.find { |m| m["type"] == "assistant_message" }
    return nil unless last_assistant_msg

    content = last_assistant_msg["text"] || ""

    # Try to extract plan section
    if content.include?("[STATUS: PLAN_READY]")
      # Remove the status marker and return the rest
      content.gsub("[STATUS: PLAN_READY]", "").strip
    else
      # Return the full content as the plan
      content
    end
  end

  def format_messages(messages)
    messages.map do |msg|
      {
        type: msg["type"],
        text: msg["text"],
        timestamp: msg["timestamp"]
      }
    end
  end
end
