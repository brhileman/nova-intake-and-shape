import { Controller } from "@hotwired/stimulus"

// Simple collapse/expand controller for sections
export default class extends Controller {
  static targets = ["content", "icon"]

  connect() {
    // Initialize collapsed state
    this.expanded = false
  }

  toggle() {
    this.expanded = !this.expanded
    
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.expanded)
    }
    
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expanded)
    }
  }
}
