import { Controller } from "@hotwired/stimulus"

// Handles the plan review page with Preview/Edit toggle,
// auto-save, agent follow-up chat, and Send to Asana
export default class extends Controller {
  static targets = [
    "editor",
    "preview",
    "previewContent",
    "editButton",
    "previewButton",
    "saveStatus",
    "chatInput",
    "agentStatus",
    "agentStatusText",
    "sendButton"
  ]

  static values = {
    requestId: Number,
    updateUrl: String,
    commentUrl: String,
    pollUrl: String,
    agentAvailable: Boolean
  }

  connect() {
    this.mode = "preview" // Start in preview mode
    this.saveTimeout = null
    this.pollInterval = null
    this.isAgentProcessing = false
  }

  disconnect() {
    this.stopPolling()
    if (this.saveTimeout) clearTimeout(this.saveTimeout)
  }

  // Toggle to edit mode
  showEdit() {
    this.mode = "edit"
    this.editorTarget.classList.remove("hidden")
    this.previewTarget.classList.add("hidden")
    // Active state for Edit button
    this.editButtonTarget.classList.remove("text-slate-400", "hover:text-slate-200")
    this.editButtonTarget.classList.add("bg-cyan-600", "text-white", "shadow-md")
    // Inactive state for Preview button
    this.previewButtonTarget.classList.remove("bg-cyan-600", "text-white", "shadow-md")
    this.previewButtonTarget.classList.add("text-slate-400", "hover:text-slate-200")
    this.editorTarget.focus()
  }

  // Toggle to preview mode
  showPreview() {
    this.mode = "preview"
    this.editorTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")
    // Active state for Preview button
    this.previewButtonTarget.classList.remove("text-slate-400", "hover:text-slate-200")
    this.previewButtonTarget.classList.add("bg-cyan-600", "text-white", "shadow-md")
    // Inactive state for Edit button
    this.editButtonTarget.classList.remove("bg-cyan-600", "text-white", "shadow-md")
    this.editButtonTarget.classList.add("text-slate-400", "hover:text-slate-200")

    // Refresh preview content from editor
    this.refreshPreview()

    // Auto-save on switching to preview
    this.debouncedSave()
  }

  // Called on keyup in the editor textarea
  onEditorInput() {
    this.debouncedSave()
  }

  debouncedSave() {
    if (this.saveTimeout) clearTimeout(this.saveTimeout)
    this.saveTimeout = setTimeout(() => this.save(), 1500)
  }

  async save() {
    const content = this.editorTarget.value
    if (!content.trim()) return

    this.updateSaveStatus("Saving...")

    try {
      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ plan_content: content })
      })

      const data = await response.json()

      if (data.success) {
        this.updateSaveStatus("Saved")
        setTimeout(() => this.updateSaveStatus(""), 2000)
      } else {
        this.updateSaveStatus("Save failed")
      }
    } catch (error) {
      console.error("Save error:", error)
      this.updateSaveStatus("Save failed")
    }
  }

  updateSaveStatus(text) {
    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = text
    }
  }

  // Render markdown preview from editor content (using server-side rendering via fetch)
  async refreshPreview() {
    if (!this.hasPreviewContentTarget) return
    const content = this.editorTarget.value

    // Simple client-side markdown rendering for preview
    this.previewContentTarget.innerHTML = this.basicMarkdown(content)
  }

  // Basic client-side markdown for preview (the final rendered version uses server-side)
  basicMarkdown(text) {
    let html = this.escapeHtml(text)

    // Headers
    html = html.replace(/^### (.+)$/gm, '<h3 class="text-base font-semibold text-slate-200 mt-4 mb-2">$1</h3>')
    html = html.replace(/^## (.+)$/gm, '<h2 class="text-lg font-semibold text-slate-100 mt-5 mb-2">$1</h2>')
    html = html.replace(/^# (.+)$/gm, '<h1 class="text-xl font-bold text-white mt-6 mb-3">$1</h1>')

    // Bold
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong class="text-slate-100">$1</strong>')

    // Italic
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>')

    // Code blocks
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre class="bg-slate-900 p-3 rounded-lg mt-2 overflow-x-auto text-xs"><code>$2</code></pre>')

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code class="bg-slate-900 px-1.5 py-0.5 rounded text-cyan-300 text-xs">$1</code>')

    // Unordered lists
    html = html.replace(/^- (.+)$/gm, '<li class="ml-4 text-slate-300">$1</li>')
    html = html.replace(/(<li[^>]*>.*<\/li>\n?)+/g, '<ul class="list-disc space-y-1 my-2">$&</ul>')

    // Numbered lists
    html = html.replace(/^\d+\.\s+(.+)$/gm, '<li class="ml-4 text-slate-300">$1</li>')

    // Line breaks
    html = html.replace(/\n\n/g, '</p><p class="text-slate-300 mt-2">')
    html = html.replace(/\n/g, '<br>')

    return `<div class="prose prose-invert prose-slate max-w-none text-sm"><p class="text-slate-300">${html}</p></div>`
  }

  // ---- Agent chat ----

  // Send a follow-up message to the agent
  async sendMessage(event) {
    event.preventDefault()

    if (!this.hasChatInputTarget) return
    const message = this.chatInputTarget.value.trim()
    if (!message) return

    this.chatInputTarget.value = ""
    this.setAgentProcessing(true, "Agent is updating the plan...")

    try {
      const response = await fetch(this.commentUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ message })
      })

      const data = await response.json()

      if (!data.success) {
        this.setAgentProcessing(false)
        this.flashStatus(data.error || "Failed to send message. Please try again.", true)
        return
      }

      // Start polling for agent response
      this.startPolling()
    } catch (error) {
      console.error("Send message error:", error)
      this.setAgentProcessing(false)
      this.flashStatus("Failed to send message. Please try again.", true)
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollInterval = setInterval(() => this.pollAgent(), 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async pollAgent() {
    try {
      const response = await fetch(this.pollUrlValue, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      const data = await response.json()

      if (data.status === "finished") {
        this.stopPolling()
        this.setAgentProcessing(false)

        // Update the plan content in the editor and preview
        if (data.plan_content) {
          this.editorTarget.value = data.plan_content
          this.refreshPreview()
          this.flashStatus("Plan updated successfully.")
        }
      } else if (data.status === "error") {
        this.stopPolling()
        this.setAgentProcessing(false)
        this.flashStatus(`Error: ${data.error}`, true)
      }
      // Keep polling if "processing"
    } catch (error) {
      console.error("Poll error:", error)
      this.stopPolling()
      this.setAgentProcessing(false)
      this.flashStatus("Lost connection to agent.", true)
    }
  }

  setAgentProcessing(processing, message) {
    this.isAgentProcessing = processing
    if (this.hasAgentStatusTarget) {
      this.agentStatusTarget.classList.toggle("hidden", !processing)
    }
    if (this.hasAgentStatusTextTarget && message) {
      this.agentStatusTextTarget.textContent = message
    }
    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = processing
    }
    if (this.hasChatInputTarget) {
      this.chatInputTarget.disabled = processing
    }
  }

  // Show a brief status message in the agent status area, then auto-hide
  flashStatus(message, isError = false) {
    if (!this.hasAgentStatusTarget || !this.hasAgentStatusTextTarget) return

    // Stop the spinner and show the message
    const spinner = this.agentStatusTarget.querySelector("svg")
    if (spinner) spinner.classList.add("hidden")

    this.agentStatusTextTarget.textContent = message
    if (isError) {
      this.agentStatusTextTarget.classList.add("text-red-400")
    }
    this.agentStatusTarget.classList.remove("hidden")

    // Auto-hide after 3 seconds
    setTimeout(() => {
      this.agentStatusTarget.classList.add("hidden")
      if (spinner) spinner.classList.remove("hidden")
      if (isError) {
        this.agentStatusTextTarget.classList.remove("text-red-400")
      }
    }, 3000)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
