import { Controller } from "@hotwired/stimulus"

// Polls for updates when decomposition plan agent is working
// Stops polling when status changes to "ready" or "needs_clarification"
// Restarts polling when user sends follow-up
export default class extends Controller {
  static values = {
    pollUrl: String,
    planId: Number,
    projectId: Number,
    interval: { type: Number, default: 2000 },  // 2 seconds - fast for responsiveness
    active: { type: Boolean, default: false }
  }

  connect() {
    this.boundHandleStreamRender = this.handleStreamRender.bind(this)
    
    // Start polling if marked as active
    if (this.activeValue) {
      this.startPolling()
    }
    
    // Listen for Turbo stream updates to detect status changes
    document.addEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  handleStreamRender(event) {
    // Re-evaluate polling after any Turbo update
    // Use a longer timeout to ensure DOM is fully updated
    setTimeout(() => this.evaluatePolling(), 200)
  }

  evaluatePolling() {
    const status = this.getStatus()
    console.log(`[DecompositionPlan ${this.planIdValue}] Evaluating polling - status: ${status}`)
    
    if (this.shouldPoll()) {
      this.startPolling()
    } else {
      this.stopPolling()
    }
  }

  startPolling() {
    if (!this.polling && this.pollUrlValue) {
      console.log(`[DecompositionPlan ${this.planIdValue}] Starting polling - status:`, this.getStatus())
      // Poll immediately, then every interval
      this.poll()
      this.polling = setInterval(() => this.poll(), this.intervalValue)
    }
  }

  stopPolling() {
    if (this.polling) {
      console.log(`[DecompositionPlan ${this.planIdValue}] Stopping polling - status:`, this.getStatus())
      clearInterval(this.polling)
      this.polling = null
    }
  }

  getStatus() {
    const wrapper = document.getElementById("decomposition_plan_status_value")
    if (!wrapper) return ""
    return wrapper.dataset?.status || ""
  }

  shouldPoll() {
    const status = this.getStatus()
    // Only poll when status is "planning" (agent is working)
    return status === "planning"
  }

  async poll() {
    if (!this.pollUrlValue) return

    try {
      const response = await fetch(this.pollUrlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error(`[DecompositionPlan ${this.planIdValue}] Polling error:`, error)
    }
  }
}
