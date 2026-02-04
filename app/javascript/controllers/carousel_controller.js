import { Controller } from "@hotwired/stimulus"

// Carousel controller for horizontal scrolling with overflow detection
export default class extends Controller {
  static targets = ["container", "scrollButton"]

  connect() {
    // Check overflow on initial load
    this.checkOverflow()
  }

  checkOverflow() {
    const container = this.containerTarget
    const hasOverflow = container.scrollWidth > container.clientWidth
    const isScrolledToEnd = container.scrollLeft + container.clientWidth >= container.scrollWidth - 10

    if (hasOverflow && !isScrolledToEnd) {
      this.scrollButtonTarget.classList.remove("hidden")
    } else {
      this.scrollButtonTarget.classList.add("hidden")
    }
  }

  scrollRight() {
    const container = this.containerTarget
    const scrollAmount = 200 // Scroll by roughly 2 project cards
    
    container.scrollTo({
      left: container.scrollLeft + scrollAmount,
      behavior: "smooth"
    })

    // Re-check overflow after scroll animation
    setTimeout(() => this.checkOverflow(), 300)
  }
}
