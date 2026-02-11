// Space-themed loading messages (goofy edition)
export const loadingMessages = [
  "Calculating trajectory...",
  "Consulting the space penguins...",
  "Warming up the warp drive...",
  "Unfurling solar sails...",
  "Aligning with distant nebulas...",
  "Crunching cosmic numbers...",
  "Asking nicely to the aliens...",
  "Refueling the rocket hamsters...",
  "Dodging asteroid paperwork...",
  "Syncing with lunar vibes...",
  "Downloading more stars...",
  "Calibrating the flux capacitor...",
  "Negotiating with space pirates...",
  "Polishing the moon rocks...",
  "Defragging the space-time continuum...",
  "Bribing the gravity well...",
  "Feeding the void snacks...",
  "Reticulating splines in zero-G...",
  "Charging up the hyperdrive...",
  "Translating from Martian...",
]

export const getRandomLoadingMessage = () => {
  return loadingMessages[Math.floor(Math.random() * loadingMessages.length)]
}

// Creates a rotating loading text manager
// Returns an object with start() and stop() methods
export const createLoadingTextRotator = (element, options = {}) => {
  const { intervalMin = 5000, intervalMax = 10000 } = options
  let timeoutId = null

  const rotateText = () => {
    if (!element) return
    element.textContent = getRandomLoadingMessage()
    // Schedule next rotation with random interval
    const interval = intervalMin + Math.random() * (intervalMax - intervalMin)
    timeoutId = setTimeout(rotateText, interval)
  }

  return {
    start() {
      if (!element) return
      // Set initial message immediately
      element.textContent = getRandomLoadingMessage()
      // Schedule first rotation
      const interval = intervalMin + Math.random() * (intervalMax - intervalMin)
      timeoutId = setTimeout(rotateText, interval)
    },
    stop() {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }
    }
  }
}
