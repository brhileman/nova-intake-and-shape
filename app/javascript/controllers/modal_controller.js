import { Controller } from "@hotwired/stimulus"

// Modal controller for opening/closing modals
// Supports multiple dialog targets per controller instance.
//
// Usage:
//   data-controller="modal" on the container
//   data-action="click->modal#open" on trigger buttons (opens first dialog)
//   data-modal-target="dialog" on dialog elements
//
// For multiple dialogs, use the target name in the action param:
//   data-action="click->modal#open" data-modal-target="asanaDialog"
//   The button opens the dialog target named in its own data-modal-target attribute.
export default class extends Controller {
  static targets = ["dialog", "asanaDialog"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  open(event) {
    event.preventDefault()
    // Determine which dialog to open based on the trigger's data-modal-target
    const triggerTarget = event.currentTarget.getAttribute("data-modal-target")
    const dialog = this._findDialog(triggerTarget)
    if (dialog) {
      dialog.showModal()
      document.body.classList.add("overflow-hidden")
    }
  }

  close(event) {
    if (event) event.preventDefault()
    // Close any open dialog
    this._allDialogs().forEach(d => {
      if (d.open) {
        d.close()
      }
    })
    document.body.classList.remove("overflow-hidden")
  }

  backdropClick(event) {
    if (event.target.tagName === "DIALOG" && event.target.open) {
      event.target.close()
      document.body.classList.remove("overflow-hidden")
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this._allDialogs().forEach(d => {
        if (d.open) {
          d.close()
          document.body.classList.remove("overflow-hidden")
        }
      })
    }
  }

  _findDialog(targetName) {
    if (targetName === "asanaDialog" && this.hasAsanaDialogTarget) {
      return this.asanaDialogTarget
    }
    if (this.hasDialogTarget) {
      return this.dialogTarget
    }
    return null
  }

  _allDialogs() {
    const dialogs = []
    if (this.hasDialogTarget) dialogs.push(this.dialogTarget)
    if (this.hasAsanaDialogTarget) dialogs.push(this.asanaDialogTarget)
    return dialogs
  }
}
