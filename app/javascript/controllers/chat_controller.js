import { Controller } from "@hotwired/stimulus"

// Manages chat thread behavior: auto-scroll and keyboard shortcuts
export default class extends Controller {
  static targets = ["messages", "input"]

  connect() {
    this.scrollToBottom()
    
    // Listen for Turbo frame updates to auto-scroll
    this.element.addEventListener("turbo:frame-load", () => this.scrollToBottom())
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  // Submit form on Enter (without Shift)
  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      const form = this.inputTarget.closest("form")
      if (form && this.inputTarget.value.trim()) {
        form.requestSubmit()
      }
    }
  }
}
