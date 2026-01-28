# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Include FactoryBot methods
  include FactoryBot::Syntax::Methods

  # Setup mock for Cursor API before each test
  setup do
    stub_cursor_api
  end

  private

  def stub_cursor_api
    # Mock agent creation
    stub_request(:post, %r{api\.cursor\.com/v1/agents})
      .to_return(
        status: 200,
        body: { id: "test-agent-#{SecureRandom.hex(8)}", status: "running" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock agent status
    stub_request(:get, %r{api\.cursor\.com/v1/agents/.*})
      .to_return(
        status: 200,
        body: {
          id: "test-agent-123",
          status: "completed",
          summary: "Task completed successfully",
          target: { prUrl: "https://github.com/test/repo/pull/1" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock conversation
    stub_request(:get, %r{api\.cursor\.com/v1/agents/.*/conversation})
      .to_return(
        status: 200,
        body: {
          messages: [
            { type: "assistant_message", text: "I've analyzed your request. Here's what I understand:\n\n**Type:** new\n\n**As a** user\n**I want** to add a dark mode toggle\n**So that** I can use the app comfortably at night" },
            { type: "user_message", text: "Looks good, please proceed" },
            { type: "assistant_message", text: "Great! The brief is confirmed. Ready for planning phase." }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock followup
    stub_request(:post, %r{api\.cursor\.com/v1/agents/.*/followup})
      .to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
