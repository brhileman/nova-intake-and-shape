import { Controller } from "@hotwired/stimulus"

// Handles the editable plan textarea with auto-save functionality
export default class extends Controller {
  static targets = ["textarea", "status", "editMode", "previewMode", "previewContent", "editBtn", "previewBtn"]
  static values = { 
    url: String,
    lastSaved: String
  }

  connect() {
    this.saveTimeout = null
    this.pendingSave = false
    this.retryCount = 0
    this.maxRetries = 3
    this.isPreviewMode = true  // Default to preview mode
    
    // Initialize lastSaved with current content
    if (this.hasTextareaTarget) {
      this.lastSavedValue = this.textareaTarget.value
    }
    
    // Set up before unload warning
    window.addEventListener("beforeunload", this.beforeUnload.bind(this))
  }

  disconnect() {
    this.stopSaveTimeout()
    window.removeEventListener("beforeunload", this.beforeUnload.bind(this))
  }

  // Toggle to preview mode
  showPreview() {
    if (this.isPreviewMode) return
    this.isPreviewMode = true
    
    // Update preview content with current textarea value
    if (this.hasPreviewContentTarget && this.hasTextareaTarget) {
      const content = this.textareaTarget.value
      if (content) {
        // Simple markdown rendering for preview
        this.previewContentTarget.innerHTML = this.renderMarkdown(content)
      } else {
        this.previewContentTarget.innerHTML = '<p class="text-slate-500 italic">No plan content yet.</p>'
      }
    }
    
    // Toggle visibility
    if (this.hasEditModeTarget) this.editModeTarget.classList.add("hidden")
    if (this.hasPreviewModeTarget) this.previewModeTarget.classList.remove("hidden")
    
    // Update button styles
    this.updateToggleButtons()
  }

  // Toggle to edit mode
  showEdit() {
    if (!this.isPreviewMode) return
    this.isPreviewMode = false
    
    // Toggle visibility
    if (this.hasPreviewModeTarget) this.previewModeTarget.classList.add("hidden")
    if (this.hasEditModeTarget) this.editModeTarget.classList.remove("hidden")
    
    // Update button styles
    this.updateToggleButtons()
    
    // Focus textarea
    if (this.hasTextareaTarget) {
      this.textareaTarget.focus()
    }
  }

  updateToggleButtons() {
    const activeClass = "bg-slate-700 text-white"
    const inactiveClass = "text-slate-400 hover:text-white"
    
    if (this.hasEditBtnTarget) {
      this.editBtnTarget.className = `px-3 py-1 text-xs font-medium rounded transition-colors ${this.isPreviewMode ? inactiveClass : activeClass}`
    }
    if (this.hasPreviewBtnTarget) {
      this.previewBtnTarget.className = `px-3 py-1 text-xs font-medium rounded transition-colors ${this.isPreviewMode ? activeClass : inactiveClass}`
    }
  }

  // Simple client-side markdown rendering
  renderMarkdown(text) {
    if (!text) return ""
    
    return text
      // Headers
      .replace(/^### (.+)$/gm, '<h3 class="text-base font-semibold text-slate-200 mt-4 mb-2">$1</h3>')
      .replace(/^## (.+)$/gm, '<h2 class="text-lg font-semibold text-slate-100 mt-6 mb-3 border-b border-slate-700 pb-2">$1</h2>')
      .replace(/^# (.+)$/gm, '<h1 class="text-xl font-bold text-white mt-6 mb-4">$1</h1>')
      // Bold
      .replace(/\*\*([^*]+)\*\*/g, '<strong class="font-semibold text-slate-100">$1</strong>')
      // Italic
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      // Code blocks
      .replace(/```([^`]+)```/gs, '<pre class="bg-slate-900 p-3 rounded-md text-sm overflow-x-auto my-3 text-slate-300"><code>$1</code></pre>')
      // Inline code
      .replace(/`([^`]+)`/g, '<code class="bg-slate-900 px-1.5 py-0.5 rounded text-sm text-cyan-400">$1</code>')
      // Checkboxes
      .replace(/^- \[ \] (.+)$/gm, '<div class="flex items-start gap-2 my-1"><span class="text-slate-500">☐</span><span>$1</span></div>')
      .replace(/^- \[x\] (.+)$/gim, '<div class="flex items-start gap-2 my-1"><span class="text-emerald-400">☑</span><span class="line-through text-slate-500">$1</span></div>')
      // Unordered lists
      .replace(/^- (.+)$/gm, '<li class="ml-4 my-1">$1</li>')
      // Ordered lists
      .replace(/^(\d+)\. (.+)$/gm, '<li class="ml-4 my-1"><span class="text-slate-400 mr-2">$1.</span>$2</li>')
      // Horizontal rules
      .replace(/^---$/gm, '<hr class="border-slate-700 my-4">')
      // Line breaks (convert double newlines to paragraphs, single to <br>)
      .replace(/\n\n/g, '</p><p class="my-2 text-slate-300">')
      .replace(/\n/g, '<br>')
      // Wrap in paragraph
      .replace(/^/, '<p class="my-2 text-slate-300">')
      .replace(/$/, '</p>')
  }

  // Called on input events from textarea
  contentChanged() {
    // Skip if content unchanged
    if (this.textareaTarget.value === this.lastSavedValue) {
      return
    }
    
    // Cancel any pending save
    this.stopSaveTimeout()
    
    // Debounce - wait 800ms after user stops typing
    this.saveTimeout = setTimeout(() => this.save(), 800)
    
    // Show "unsaved" indicator
    this.showStatus("Unsaved changes...", "warning")
  }

  async save() {
    if (!this.hasTextareaTarget || !this.urlValue) return
    
    const content = this.textareaTarget.value
    
    // Skip if content hasn't changed
    if (content === this.lastSavedValue) {
      return
    }
    
    this.pendingSave = true
    this.showStatus("Saving...", "info")
    
    try {
      await this.saveWithRetry(content)
      this.lastSavedValue = content
      this.pendingSave = false
      this.retryCount = 0
      this.showStatus("Saved", "success")
      
      // Clear the saved status after 3 seconds
      setTimeout(() => {
        if (!this.pendingSave && !this.hasUnsavedChanges()) {
          this.clearStatus()
        }
      }, 3000)
    } catch (error) {
      this.pendingSave = false
      this.showStatus("Save failed. Click to retry.", "error")
    }
  }

  async saveWithRetry(content) {
    const maxAttempts = this.maxRetries
    let lastError = null
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const response = await fetch(this.urlValue, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": this.csrfToken
          },
          body: JSON.stringify({
            plan_content: content
          })
        })
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`)
        }
        
        const data = await response.json()
        if (data.success) {
          return data
        } else {
          throw new Error(data.error || "Save failed")
        }
      } catch (error) {
        lastError = error
        this.retryCount++
        
        if (attempt < maxAttempts - 1) {
          // Exponential backoff: 1s, 2s, 4s
          const delay = Math.pow(2, attempt) * 1000
          this.showStatus(`Save failed, retrying... (${attempt + 1}/${maxAttempts})`, "warning")
          await this.sleep(delay)
        }
      }
    }
    
    throw lastError
  }

  // Manual retry when clicking on error status
  retryStatus(event) {
    if (this.hasUnsavedChanges()) {
      this.save()
    }
  }

  hasUnsavedChanges() {
    if (!this.hasTextareaTarget) return false
    return this.textareaTarget.value !== this.lastSavedValue
  }

  beforeUnload(event) {
    if (this.pendingSave || this.hasUnsavedChanges()) {
      event.preventDefault()
      event.returnValue = "You have unsaved changes. Are you sure you want to leave?"
      return event.returnValue
    }
  }

  showStatus(message, type = "info") {
    if (!this.hasStatusTarget) return
    
    const colors = {
      info: "text-slate-400",
      success: "text-emerald-400",
      warning: "text-amber-400",
      error: "text-red-400 cursor-pointer hover:underline"
    }
    
    this.statusTarget.textContent = message
    this.statusTarget.className = `text-xs ${colors[type] || colors.info}`
    
    if (type === "error") {
      this.statusTarget.setAttribute("data-action", "click->plan-editor#retryStatus")
    } else {
      this.statusTarget.removeAttribute("data-action")
    }
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ""
    }
  }

  stopSaveTimeout() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
      this.saveTimeout = null
    }
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
