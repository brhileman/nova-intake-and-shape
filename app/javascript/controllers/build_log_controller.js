import { Controller } from "@hotwired/stimulus"

// Handles the build log panel interactions
export default class extends Controller {
  static targets = ["input", "typingIndicator"]

  connect() {
    this.isWaiting = false
  }

  // Called when form is submitted
  sendMessage(event) {
    const input = this.inputTarget
    const message = input.value.trim()
    
    if (!message) {
      event.preventDefault()
      return
    }
    
    // Show typing indicator
    this.showTypingIndicator()
    
    // Clear the input after a brief delay (allows form to submit first)
    setTimeout(() => {
      input.value = ""
    }, 100)
  }

  showTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove("hidden")
      this.isWaiting = true
      
      // Scroll to bottom to show indicator
      const messagesContainer = this.typingIndicatorTarget.closest(".overflow-y-auto")
      if (messagesContainer) {
        messagesContainer.scrollTop = messagesContainer.scrollHeight
      }
    }
  }

  hideTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add("hidden")
      this.isWaiting = false
    }
  }

  // Called when turbo stream updates the messages
  messagesUpdated() {
    this.hideTypingIndicator()
    
    // Scroll to bottom
    const messagesContainer = this.element.querySelector(".overflow-y-auto")
    if (messagesContainer) {
      messagesContainer.scrollTop = messagesContainer.scrollHeight
    }
  }
}
