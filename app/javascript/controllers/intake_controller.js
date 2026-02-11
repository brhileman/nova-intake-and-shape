import { Controller } from "@hotwired/stimulus"

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
  }

  disconnect() {
    this.stopPolling()
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

    try {
      const response = await fetch("/intake/message", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ message })
      })

      const data = await response.json()

      if (!data.success) {
        this.addMessage("system", `Error: ${data.error}`)
        return
      }

      // Restart polling to get the agent's response
      this.startPolling()
    } catch (error) {
      console.error("Send message error:", error)
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

      // Update messages if in chat mode
      if (data.status === "needs_clarification") {
        this.updateMessages(data.messages)
        this.showChat()
        this.stopPolling()
      } else if (data.status === "plan_ready") {
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
    // Create the actual request with the plan
    try {
      const response = await fetch("/requests", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          request: { original_input: this.originalInput },
          plan_content: planContent
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
  }

  showChat() {
    this.inputFormTarget.classList.add("hidden")
    this.processingAreaTarget.classList.add("hidden")
    this.chatAreaTarget.classList.remove("hidden")
    this.chatInputTarget.focus()
  }

  showError(message) {
    alert(message)
    // Reset to input form
    this.processingAreaTarget.classList.add("hidden")
    if (this.hasChatAreaTarget) {
      this.chatAreaTarget.classList.add("hidden")
    }
    this.inputFormTarget.classList.remove("hidden")
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
