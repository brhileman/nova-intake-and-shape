import { Controller } from "@hotwired/stimulus"

// Auto-scrolls container to bottom when content changes
export default class extends Controller {
  static values = {
    auto: { type: Boolean, default: true }
  }

  connect() {
    this.scrollToBottom()
    
    // Watch for DOM changes and scroll to bottom
    this.observer = new MutationObserver(() => {
      if (this.autoValue) {
        this.scrollToBottom()
      }
    })
    
    this.observer.observe(this.element, { 
      childList: true, 
      subtree: true 
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    // Small delay to ensure content is rendered
    setTimeout(() => {
      this.element.scrollTop = this.element.scrollHeight
    }, 50)
  }
}
