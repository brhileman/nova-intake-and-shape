# Nova Flow Troubleshooting Guide

## GitHub PR Creation Issues

### Error: "Resource not accessible by integration"

**Context**: This error occurs when the Cursor API tries to create a PR on GitHub but lacks the necessary permissions.

**Root Cause**: Nova Flow uses the Cursor Background Agents API with `autoCreatePr: true`. The Cursor API handles the GitHub integration internally. The error indicates that Cursor's GitHub integration doesn't have permission to create PRs on the target repository.

**Troubleshooting Steps**:

1. **Verify Cursor GitHub App Installation**
   - Go to your GitHub repository settings
   - Navigate to "Integrations" or "GitHub Apps"
   - Ensure the Cursor GitHub App is installed and has access to the repository
   - Verify it has "Pull Requests: Write" permission

2. **Check Repository Visibility**
   - If the repository is private, ensure Cursor has been granted access to private repos
   - Try with a public repository to isolate if it's a private repo issue

3. **Branch Protection Rules**
   - Check if branch protection rules are blocking PR creation
   - Some rules may prevent automated PR creation

4. **Cursor API Authentication**
   - Verify your `CURSOR_API_KEY` is valid and active
   - Check if your Cursor subscription includes Background Agent features

5. **Manual PR Creation Workaround**
   - When this error occurs, the agent typically pushes a branch but can't create the PR
   - The branch URL is usually provided in the error message
   - You can manually create the PR at: `https://github.com/[owner]/[repo]/pull/new/[branch-name]`

**Relevant Code Locations**:
- Agent PR creation: `app/services/agents/execution_agent.rb` (sets `auto_create_pr?: true`)
- Cursor API client: `app/services/cursor_api/client.rb` (sends `autoCreatePr` flag)
- PR URL extraction: `app/controllers/requests_controller.rb#save_execution_from_agent`

**Environment Variables**:
- `CURSOR_API_KEY`: Required for Cursor API authentication

## Common Issues

### Agent Not Progressing

**Symptoms**: Agent status shows "RUNNING" but no progress is visible.

**Troubleshooting**:
1. Check the Cursor Dashboard for agent status
2. Use the "Check Status" button to manually poll
3. Verify the project's `environment_configured` flag is `true`

### Missing Extracted Data

**Symptoms**: Title, user story, or other extracted fields show "Not extracted from brief"

**Cause**: The agent's response didn't match the expected format patterns.

**Solution**:
- The raw brief/plan content is still saved even if extraction fails
- Check the Brief or Plan artifact for the full agent response
- Future enhancement: Add manual edit capability for extracted fields

### Slow Page Loading

**Symptoms**: Page takes a long time to update after clicking approve.

**Solution**: The system now uses Turbo Streams for instant updates. If you experience slow loading:
1. Check browser console for JavaScript errors
2. Verify Turbo is properly loaded
3. Check network tab for failed requests
