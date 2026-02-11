import { Controller } from "@hotwired/stimulus"
import { createLoadingTextRotator } from "utils/loading_messages"

// Handles the decomposition plan form submission with loading states
export default class extends Controller {
  static targets = ["form", "loading", "input", "submitBtn", "btnText", "spinner", "loadingText"]

  connect() {
    this.loadingTextRotator = null
  }

  disconnect() {
    this.stopLoadingTextRotation()
  }

  submit(event) {
    // Validate input
    if (this.hasInputTarget && this.inputTarget.value.trim() === "") {
      event.preventDefault()
      this.inputTarget.focus()
      return
    }

    // Show loading state on button
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.classList.add("opacity-75", "cursor-wait")
    }
    
    if (this.hasBtnTextTarget) {
      this.btnTextTarget.textContent = "Starting..."
    }
    
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }

    // After a short delay, show the full loading state
    // This gives immediate feedback while the form submits
    setTimeout(() => {
      if (this.hasFormTarget && this.hasLoadingTarget) {
        this.formTarget.classList.add("hidden")
        this.loadingTarget.classList.remove("hidden")
        this.startLoadingTextRotation()
      }
    }, 300)
  }

  startLoadingTextRotation() {
    if (this.hasLoadingTextTarget && !this.loadingTextRotator) {
      this.loadingTextRotator = createLoadingTextRotator(this.loadingTextTarget)
      this.loadingTextRotator.start()
    }
  }

  stopLoadingTextRotation() {
    if (this.loadingTextRotator) {
      this.loadingTextRotator.stop()
      this.loadingTextRotator = null
    }
  }
}
