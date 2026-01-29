import { Controller } from "@hotwired/stimulus"

// Modal controller for opening/closing modals
// Usage: data-controller="modal" on the container
//        data-action="click->modal#open" on trigger buttons
//        data-modal-target="dialog" on the dialog element
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    // Close on escape key
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.dialogTarget.close()
    document.body.classList.remove("overflow-hidden")
  }

  // Close when clicking backdrop (outside the modal content)
  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.dialogTarget.open) {
      this.close()
    }
  }
}
