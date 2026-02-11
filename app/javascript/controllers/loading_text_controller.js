import { Controller } from "@hotwired/stimulus"
import { createLoadingTextRotator } from "utils/loading_messages"

// Automatically rotates loading text when the element is visible
export default class extends Controller {
  static targets = ["text"]

  connect() {
    this.rotator = null
    this.startRotation()
  }

  disconnect() {
    this.stopRotation()
  }

  startRotation() {
    const textEl = this.hasTextTarget ? this.textTarget : this.element
    if (textEl && !this.rotator) {
      this.rotator = createLoadingTextRotator(textEl)
      this.rotator.start()
    }
  }

  stopRotation() {
    if (this.rotator) {
      this.rotator.stop()
      this.rotator = null
    }
  }
}
