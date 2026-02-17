import { Controller } from "@hotwired/stimulus"
import { createLoadingTextRotator } from "utils/loading_messages"

// Handles the ephemeral intake flow before a Request record is created
// Flow: Input -> Processing -> (if clarification needed) Chat -> Create Request
export default class extends Controller {
  static targets = [
    "inputForm",
    "input",
    "submitButton",
    "processingArea",
    "processingStatus",
    "chatArea",
    "messages",
    "chatInput"
  ]

  static values = {
    projectId: Number
  }

  connect() {
    this.agentId = null
    this.pollInterval = null
    this.originalInput = null
    this.loadingRotator = null
    this.loadingDelayTimeout = null
  }

  disconnect() {
    this.stopPolling()
    this.stopLoadingRotator()
  }

  // Called when user clicks "Submit Request"
  async submit(event) {
    event.preventDefault()

    const input = this.inputTarget.value.trim()
    if (!input) {
      alert("Please describe your request.")
      return
    }

    this.originalInput = input

    // Show processing state
    this.showProcessing()

    try {
      const response = await fetch("/intake/start", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ original_input: input })
      })

      const data = await response.json()

      if (!data.success) {
        this.showError(data.error || "Failed to start intake process.")
        return
      }

      this.agentId = data.agent_id
      this.startPolling()
    } catch (error) {
      console.error("Intake start error:", error)
      this.showError("Failed to connect to server. Please try again.")
    }
  }

  // Called when user sends a chat message
  async sendMessage(event) {
    event.preventDefault()

    const message = this.chatInputTarget.value.trim()
    if (!message) return

    // Add user message to UI immediately
    this.addMessage("user", message)
    this.chatInputTarget.value = ""

    // Show typing indicator while agent processes
    this.showTypingIndicator()

    try {
      const response = await fetch("/intake/message", {
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
        this.removeTypingIndicator()
        this.addMessage("system", `Error: ${data.error}`)
        return
      }

      // Restart polling to get the agent's response
      this.startPolling()
    } catch (error) {
      console.error("Send message error:", error)
      this.removeTypingIndicator()
      this.addMessage("system", "Failed to send message. Please try again.")
    }
  }

  startPolling() {
    this.stopPolling()
    this.poll() // Poll immediately
    this.pollInterval = setInterval(() => this.poll(), 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async poll() {
    try {
      const response = await fetch("/intake/poll", {
        method: "GET",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      const data = await response.json()

      if (!data.success) {
        console.error("Poll error:", data.error)
        return
      }

      this.updateStatus(data.status)

      // Restore original_input from session if we lost it (e.g., page refresh)
      if (data.original_input && !this.originalInput) {
        this.originalInput = data.original_input
      }

      // Update messages if in chat mode
      if (data.status === "needs_clarification") {
        this.removeTypingIndicator()
        this.updateMessages(data.messages)
        this.showChat()
        this.stopPolling()
      } else if (data.status === "plan_ready") {
        this.removeTypingIndicator()
        this.stopPolling()
        this.createRequest(data.plan_content)
      }
      // Keep polling if still processing
    } catch (error) {
      console.error("Poll error:", error)
    }
  }

  updateStatus(status) {
    if (this.hasProcessingStatusTarget) {
      // Don't overwrite the fun rotating messages while still processing
      if (status === "processing" && this.loadingRotator) return

      const statusMessages = {
        processing: "Agent is analyzing your request...",
        needs_clarification: "Agent needs more information...",
        plan_ready: "Plan is ready! Creating request..."
      }
      this.processingStatusTarget.textContent = statusMessages[status] || status
    }
  }

  updateMessages(messages) {
    // Only add messages we haven't seen yet
    const existingCount = this.messagesTarget.children.length
    const newMessages = messages.slice(existingCount)

    newMessages.forEach(msg => {
      if (msg.type === "assistant_message") {
        this.addMessage("assistant", msg.text)
      } else if (msg.type === "user_message") {
        this.addMessage("user", msg.text)
      }
    })
  }

  addMessage(role, text) {
    const div = document.createElement("div")
    
    if (role === "user") {
      div.className = "flex justify-end"
      div.innerHTML = `
        <div class="max-w-[80%] px-4 py-2 rounded-lg bg-cyan-600 text-white text-sm">
          ${this.escapeHtml(text)}
        </div>
      `
    } else if (role === "assistant") {
      div.className = "flex justify-start"
      div.innerHTML = `
        <div class="max-w-[80%] px-4 py-2 rounded-lg bg-slate-700 text-slate-200 text-sm">
          ${this.formatMarkdown(text)}
        </div>
      `
    } else {
      // System messages
      div.className = "flex justify-center"
      div.innerHTML = `
        <div class="px-4 py-2 text-slate-500 text-sm italic">
          ${this.escapeHtml(text)}
        </div>
      `
    }

    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  async createRequest(planContent) {
    // Validate we have the original input
    if (!this.originalInput) {
      console.error("Create request error: originalInput is missing")
      this.showError("Session expired. Please refresh the page and try again.")
      return
    }

    // Create the actual request with the plan (draft status -- user will review before sending to Asana)
    try {
      const response = await fetch("/requests", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          request: { original_input: this.originalInput },
          plan_content: planContent,
          agent_id: this.agentId
        })
      })

      const data = await response.json()

      if (data.success && data.redirect_url) {
        window.location.href = data.redirect_url
      } else if (!data.success) {
        this.showError(data.errors?.join(", ") || "Failed to create request.")
      }
    } catch (error) {
      console.error("Create request error:", error)
      this.showError("Failed to create request. Please try again.")
    }
  }

  showProcessing() {
    this.inputFormTarget.classList.add("hidden")
    this.processingAreaTarget.classList.remove("hidden")
    if (this.hasChatAreaTarget) {
      this.chatAreaTarget.classList.add("hidden")
    }
    this.startLoadingRotator()
  }

  startLoadingRotator() {
    this.stopLoadingRotator()

    if (!this.hasProcessingStatusTarget) return

    // Show the initial "analyzing" message first
    this.processingStatusTarget.textContent = "Agent is analyzing your request..."

    // After 5 seconds, switch to fun rotating messages
    this.loadingDelayTimeout = setTimeout(() => {
      this.loadingRotator = createLoadingTextRotator(this.processingStatusTarget, {
        intervalMin: 4000,
        intervalMax: 7000
      })
      this.loadingRotator.start()
    }, 5000)
  }

  stopLoadingRotator() {
    if (this.loadingDelayTimeout) {
      clearTimeout(this.loadingDelayTimeout)
      this.loadingDelayTimeout = null
    }
    if (this.loadingRotator) {
      this.loadingRotator.stop()
      this.loadingRotator = null
    }
  }

  showChat() {
    this.stopLoadingRotator()
    this.inputFormTarget.classList.add("hidden")
    this.processingAreaTarget.classList.add("hidden")
    this.chatAreaTarget.classList.remove("hidden")
    this.chatInputTarget.focus()
  }

  showError(message) {
    this.stopLoadingRotator()
    alert(message)
    // Reset to input form
    this.processingAreaTarget.classList.add("hidden")
    if (this.hasChatAreaTarget) {
      this.chatAreaTarget.classList.add("hidden")
    }
    this.inputFormTarget.classList.remove("hidden")
  }

  showTypingIndicator() {
    this.removeTypingIndicator() // Prevent duplicates
    const div = document.createElement("div")
    div.className = "flex justify-start"
    div.setAttribute("data-typing-indicator", "true")
    div.innerHTML = `
      <div class="px-4 py-3 rounded-lg bg-slate-700">
        <div class="flex items-center gap-1.5">
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
        </div>
      </div>
    `
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  removeTypingIndicator() {
    if (!this.hasMessagesTarget) return
    const indicator = this.messagesTarget.querySelector("[data-typing-indicator]")
    if (indicator) indicator.remove()
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  formatMarkdown(text) {
    // Basic markdown formatting - escape HTML first, then apply markdown
    let html = this.escapeHtml(text)
    
    // Convert code blocks
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre class="bg-slate-800 p-2 rounded mt-2 overflow-x-auto"><code>$2</code></pre>')
    
    // Convert inline code
    html = html.replace(/`([^`]+)`/g, '<code class="bg-slate-800 px-1 rounded">$1</code>')
    
    // Convert bold
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    
    // Convert line breaks
    html = html.replace(/\n/g, '<br>')
    
    return html
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
