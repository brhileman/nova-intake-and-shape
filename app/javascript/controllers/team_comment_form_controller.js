import { Controller } from "@hotwired/stimulus"

// Handles team comment form: submit on Enter, clear input after submit
export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    // Listen for turbo:submit-end to clear input after successful submission
    this.element.addEventListener("turbo:submit-end", (event) => {
      if (event.detail.success) {
        this.clearInput()
      }
    })
  }

  submit(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.hasInputTarget && this.inputTarget.value.trim()) {
        this.element.requestSubmit()
      }
    }
  }

  clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }
}
