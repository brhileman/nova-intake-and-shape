# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Asana::ClientTest < ActiveSupport::TestCase
  setup do
    @client = Asana::Client.new(access_token: "test-token")
  end

  test "raises AuthenticationError when no token provided" do
    original = ENV["ASANA_ACCESS_TOKEN"]
    ENV.delete("ASANA_ACCESS_TOKEN")

    assert_raises(Asana::Client::AuthenticationError) do
      Asana::Client.new(access_token: nil)
    end
  ensure
    ENV["ASANA_ACCESS_TOKEN"] = original if original
  end

  test "create_task sends plain-text notes when html_notes not provided" do
    stub = stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .with(
        body: hash_including(
          "data" => hash_including(
            "name" => "Test Task",
            "notes" => "Task description",
            "projects" => ["proj-123"]
          )
        ),
        headers: { "Authorization" => "Bearer test-token" }
      )
      .to_return(
        status: 201,
        body: { data: { gid: "task-456", permalink_url: "https://app.asana.com/0/0/task-456" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.create_task(project_gid: "proj-123", name: "Test Task", notes: "Task description")

    assert_requested(stub)
    assert_equal "task-456", result["gid"]
    assert_equal "https://app.asana.com/0/0/task-456", result["permalink_url"]
  end

  test "create_task sends html_notes when provided (preferred over notes)" do
    html = "<body><h2>Plan</h2><p><strong>Type:</strong> chore</p></body>"

    stub = stub_request(:post, "https://app.asana.com/api/1.0/tasks")
      .with(
        body: hash_including(
          "data" => hash_including(
            "name" => "Rich Task",
            "html_notes" => html,
            "projects" => ["proj-123"]
          )
        ),
        headers: { "Authorization" => "Bearer test-token" }
      )
      .to_return(
        status: 201,
        body: { data: { gid: "task-789", permalink_url: "https://app.asana.com/0/0/task-789" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.create_task(project_gid: "proj-123", name: "Rich Task", html_notes: html)

    assert_requested(stub)
    assert_equal "task-789", result["gid"]
  end

  test "list_workspaces returns workspace data" do
    stub_request(:get, %r{app\.asana\.com/api/1.0/workspaces})
      .to_return(
        status: 200,
        body: { data: [{ gid: "ws-1", name: "My Workspace" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.list_workspaces
    assert_equal 1, result.length
    assert_equal "My Workspace", result.first["name"]
  end

  test "raises Error on 500 response" do
    stub_request(:post, %r{app\.asana\.com/api/1.0/tasks})
      .to_return(
        status: 500,
        body: { errors: [{ message: "Internal server error" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(Asana::Client::Error) do
      @client.create_task(project_gid: "proj-123", name: "Test", notes: "")
    end
  end

  test "raises AuthenticationError on 401 response" do
    stub_request(:get, %r{app\.asana\.com/api/1.0/workspaces})
      .to_return(status: 401, body: "Unauthorized")

    assert_raises(Asana::Client::AuthenticationError) do
      @client.list_workspaces
    end
  end
end
