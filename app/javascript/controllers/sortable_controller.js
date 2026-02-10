import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Enables drag-and-drop reordering of request rows
// Only active when the "All Requests" filter is selected
export default class extends Controller {
  static values = {
    url: String,
    enabled: { type: Boolean, default: true }
  }

  connect() {
    if (!this.enabledValue) return

    this.sortable = new Sortable(this.element, {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async onEnd(event) {
    if (event.oldIndex === event.newIndex) return

    // Get all request IDs in the new order
    const rows = this.element.querySelectorAll("tr[data-request-id]")
    const requestIds = Array.from(rows).map(row => row.dataset.requestId)

    if (!this.urlValue || requestIds.length === 0) return

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "X-Requested-With": "XMLHttpRequest"
        },
        body: JSON.stringify({ request_ids: requestIds })
      })

      if (!response.ok) {
        console.error("[Sortable] Failed to save order:", response.status)
        // Optionally could revert the UI here
      }
    } catch (error) {
      console.error("[Sortable] Error saving order:", error)
    }
  }
}
