# Nova Flow - Intake & Shape

AI-powered intake and task shaping tool. PMs describe what they need, an AI agent asks clarifying questions, and produces a fully shaped task that gets pushed to Asana.

Forked from the full Nova Flow task planning and cloud agent workflow.

## How It Works

1. **PM selects a project** -- each project is linked to a GitHub repo (for agent context) and an Asana project (for task output)
2. **PM enters an intake request** -- describes what they want to build, update, or fix
3. **AI agent shapes the task** -- asks clarifying questions, analyzes the codebase, and produces a structured implementation plan
4. **Shaped task goes to Asana** -- the title, description, user story, type, and estimate are pushed as a new Asana task

## Setup

### Prerequisites

- Ruby 3.x
- PostgreSQL
- Node.js (for asset pipeline)

### Environment Variables

```bash
CURSOR_API_KEY=your-cursor-api-key       # For the AI shaping agent
ASANA_ACCESS_TOKEN=your-asana-pat        # Personal Access Token from https://app.asana.com/0/developer-console
```

### Install & Run

```bash
cd nova-flow
bundle install
bin/rails db:setup
bin/dev
```

### Configure Asana

1. Generate a Personal Access Token at https://app.asana.com/0/developer-console
2. Set `ASANA_ACCESS_TOKEN` in your environment
3. In the app, click the Asana status badge on a project to link it to an Asana project
4. New shaped tasks will automatically be pushed to the linked Asana project

## Architecture

- **Rails 8.1** with Hotwire (Turbo + Stimulus)
- **Tailwind CSS** for styling
- **Cursor Cloud Agents API** for AI-powered shaping
- **Asana REST API** for task creation
- **PostgreSQL** for local data storage

## Key Files

- `app/services/agents/` -- AI agent configuration and prompts
- `app/services/asana/` -- Asana API client and task creator
- `app/controllers/intake_controller.rb` -- Ephemeral intake flow
- `app/services/plan_extractor.rb` -- Extracts structured fields from agent output
