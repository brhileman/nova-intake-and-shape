import { Controller } from "@hotwired/stimulus"

// Handles dynamic adding/removing of Figma link rows in design guidance form
export default class extends Controller {
  static targets = ["container", "template", "row"]

  connect() {
    this.index = this.rowTargets.length
  }

  add(event) {
    event.preventDefault()
    
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return
    
    // Clone the template
    const template = this.templateTarget.content.cloneNode(true)
    
    // Replace NEW_INDEX with actual index
    const html = template.firstElementChild.outerHTML.replace(/NEW_INDEX/g, this.index.toString())
    
    // Insert the new row
    this.containerTarget.insertAdjacentHTML("beforeend", html)
    
    this.index++
    
    // Focus the URL input of the new row
    const newRow = this.containerTarget.lastElementChild
    const urlInput = newRow.querySelector('input[name*="[url]"]')
    if (urlInput) {
      urlInput.focus()
    }
  }

  remove(event) {
    event.preventDefault()
    
    const row = event.target.closest('[data-figma-links-target="row"]')
    if (!row) return
    
    // Check if row has an ID field (existing record)
    const idInput = row.querySelector('input[name*="[id]"]')
    
    if (idInput && idInput.value) {
      // Mark for destruction instead of removing
      const destroyInput = document.createElement("input")
      destroyInput.type = "hidden"
      destroyInput.name = idInput.name.replace("[id]", "[_destroy]")
      destroyInput.value = "1"
      row.appendChild(destroyInput)
      
      // Hide the row
      row.classList.add("hidden")
    } else {
      // New row, just remove it
      row.remove()
    }
  }
}
