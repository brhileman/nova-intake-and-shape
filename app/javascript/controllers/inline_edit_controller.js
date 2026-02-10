import { Controller } from "@hotwired/stimulus"

// Inline edit controller for toggling between display and edit modes
export default class extends Controller {
  static targets = ["display", "form"]

  toggle() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    
    // Focus the input
    const input = this.formTarget.querySelector("input, textarea")
    if (input) {
      input.focus()
      input.select()
    }
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  submit() {
    // Form will submit via Turbo, which will replace the element
  }
}
