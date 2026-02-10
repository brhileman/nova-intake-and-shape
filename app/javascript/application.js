// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Disable Turbo Drive link prefetching on hover
// (prevents unnecessary server requests when simply mousing over links)
Turbo.config.drive.prefetchOnLinkHover = false

// Page Loading Overlay Management
;(() => {
  let showTimeout
  let isShowing = false

  const getOverlay = () => document.getElementById("page-loading-overlay")
  const getTextEl = () => getOverlay()?.querySelector(".text")

  const showOverlay = (text = "Loading...") => {
    const overlay = getOverlay()
    const textEl = getTextEl()
    if (!overlay) return
    
    if (textEl) textEl.textContent = text
    overlay.classList.add("active")
    isShowing = true
  }

  const hideOverlay = () => {
    clearTimeout(showTimeout)
    const overlay = getOverlay()
    if (overlay) overlay.classList.remove("active")
    isShowing = false
  }

  // Show overlay on Turbo navigation start (with slight delay to avoid flash on fast loads)
  document.addEventListener("turbo:before-visit", () => {
    showTimeout = setTimeout(() => showOverlay("Loading..."), 100)
  })

  // Show overlay on form submissions that will redirect
  document.addEventListener("turbo:submit-start", (event) => {
    const form = event.target
    // Check if form expects Turbo Stream response (in which case, don't show full overlay)
    const acceptsStream = form.dataset.turboStream === "true" || 
                          form.querySelector('[data-turbo-stream="true"]')
    
    if (!acceptsStream) {
      showTimeout = setTimeout(() => showOverlay("Submitting..."), 100)
    }
  })

  // Hide overlay when page loads
  document.addEventListener("turbo:load", hideOverlay)

  // Hide overlay when form submission completes
  document.addEventListener("turbo:submit-end", hideOverlay)

  // Hide overlay on render (handles Turbo Stream updates)
  document.addEventListener("turbo:render", hideOverlay)

  // Hide overlay on error
  document.addEventListener("turbo:fetch-request-error", hideOverlay)
})()
