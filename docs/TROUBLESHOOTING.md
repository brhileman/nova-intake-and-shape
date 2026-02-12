# Nova Flow Intake & Shape - Troubleshooting Guide

## Asana Integration Issues

### Error: "No Asana access token provided"

**Cause**: The `ASANA_ACCESS_TOKEN` environment variable is not set.

**Solution**:
1. Generate a Personal Access Token at https://app.asana.com/0/developer-console
2. Set `ASANA_ACCESS_TOKEN` in your `.env` file or environment

### Error: "Invalid Asana access token" (401)

**Cause**: The PAT has expired or been revoked.

**Solution**:
1. Go to https://app.asana.com/0/developer-console
2. Revoke the old token and create a new one
3. Update the `ASANA_ACCESS_TOKEN` environment variable

### Task Created Locally but Not in Asana

**Cause**: The Asana push failed but the local record was saved.

**Solution**:
1. Check the project's Asana settings (click the Asana badge on the project page)
2. Verify the Asana project GID and workspace GID are correct
3. Check the Rails logs for the specific error message
4. Retry by creating a new intake request

## Agent Issues

### Agent Not Progressing

**Symptoms**: Status shows "Processing Your Request" but nothing happens.

**Troubleshooting**:
1. Check the Cursor Dashboard for agent status
2. Verify `CURSOR_API_KEY` is valid
3. Ensure the project's `repo_url` is accessible

### Missing Extracted Data

**Symptoms**: Title, user story, or type not extracted from the shaped task.

**Cause**: The agent's response didn't match the expected format patterns.

**Solution**:
- The full plan content is still saved even if field extraction fails
- The Asana task description will contain the complete agent output
- Check `app/services/plan_extractor.rb` for the expected format patterns

## Common Issues

### Slow Page Loading

1. Check browser console for JavaScript errors
2. Verify Turbo is properly loaded
3. Check network tab for failed requests
