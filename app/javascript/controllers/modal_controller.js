import { Controller } from "@hotwired/stimulus"

// Modal controller for opening/closing modals
// Supports multiple dialog targets per controller instance.
//
// Usage:
//   data-controller="modal" on the container
//   data-modal-target="dialog" on the default dialog element
//   data-modal-target="asanaDialog" on the asana dialog element
//   data-action="click->modal#open" on trigger buttons (opens default dialog)
//   data-modal-dialog-param="asanaDialog" on trigger to open a specific dialog
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
    // Use a data param to determine which dialog to open
    const dialogName = event.params?.dialog || "dialog"
    const dialog = this._findDialog(dialogName)
    if (dialog) {
      dialog.showModal()
      document.body.classList.add("overflow-hidden")
    }
  }

  close(event) {
    if (event) event.preventDefault()
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
