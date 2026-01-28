import { Controller } from "@hotwired/stimulus"

// Polls for updates when agent is working (*_in_progress states)
// Server checks agent status and auto-transitions to *_review when complete
// Stops polling when status changes to *_review or completed
// Restarts polling when user sends follow-up (status goes back to *_in_progress)
export default class extends Controller {
  static values = {
    url: String,
    requestId: Number,
    interval: { type: Number, default: 10000 }  // 10 seconds
  }

  connect() {
    this.boundHandleStreamRender = this.handleStreamRender.bind(this)
    this.startPollingIfNeeded()
    
    // Listen for Turbo stream updates to detect status changes
    document.addEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  handleStreamRender(event) {
    // Only respond to stream updates for THIS request
    // Check if the target matches one of our request-specific IDs
    const target = event.target?.getAttribute?.("target") || ""
    if (!target.endsWith(`_${this.requestIdValue}`)) {
      return // Ignore updates for other requests
    }
    
    // After any Turbo stream update for this request, re-evaluate polling
    setTimeout(() => this.evaluatePolling(), 100)
  }

  evaluatePolling() {
    if (this.shouldPoll()) {
      this.startPollingIfNeeded()
    } else {
      this.stopPolling()
    }
  }

  startPollingIfNeeded() {
    if (this.shouldPoll() && !this.polling) {
      console.log(`[Request ${this.requestIdValue}] Starting polling - status:`, this.getStatus())
      // Poll immediately, then every interval
      this.poll()
      this.polling = setInterval(() => this.poll(), this.intervalValue)
    }
  }

  stopPolling() {
    if (this.polling) {
      console.log(`[Request ${this.requestIdValue}] Stopping polling - status:`, this.getStatus())
      clearInterval(this.polling)
      this.polling = null
    }
  }

  getStatus() {
    // Read status from the request-specific hidden element
    const wrapper = document.getElementById(`request_status_value_${this.requestIdValue}`)
    if (!wrapper) return ""
    
    // Check wrapper first, then child element
    if (wrapper.dataset?.status) return wrapper.dataset.status
    const inner = wrapper.querySelector("[data-status]")
    return inner?.dataset?.status || ""
  }

  shouldPoll() {
    // Only poll for *_in_progress states
    const status = this.getStatus()
    return status && status.endsWith("_in_progress")
  }

  async poll() {
    if (!this.urlValue) return

    try {
      const response = await fetch(this.urlValue, {
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
      console.error(`[Request ${this.requestIdValue}] Polling error:`, error)
    }
  }
}
