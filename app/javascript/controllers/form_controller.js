import { Controller } from "@hotwired/stimulus"

// Handles form submission states: disable button, show loading, clear input
export default class extends Controller {
  static targets = ["submit", "input"]

  disable() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.originalText = this.submitTarget.value || this.submitTarget.textContent
      this.submitTarget.value = "Sending..."
    }
  }

  enable() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      if (this.originalText) {
        this.submitTarget.value = this.originalText
      }
    }
    
    // Clear input after successful submit
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }

    // Also clear any textarea in the form
    const textarea = this.element.querySelector("textarea")
    if (textarea) {
      textarea.value = ""
    }
  }
}
