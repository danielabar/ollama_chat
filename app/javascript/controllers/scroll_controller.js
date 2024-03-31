import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { delay: Number };

  connect() {
    this.setupObserver();
  }

  /**
   * Scrolls the element to the bottom after a specified delay.
   */
  scrollBottom() {
    setTimeout(() => {
      this.element.scrollTop = this.element.scrollHeight;
    }, this.delayValue || 0);
  }

  /**
   * Checks if scrolling is needed and performs scrolling if necessary.
   * It calculates the difference between the bottom of the scrollable area
   * and the visible area, and if it exceeds a specified threshold, it calls
   * the scrollBottom method to perform scrolling.
   *
   * scrollHeight:
   *  measurement of the height of an element's content, including content not visible on the screen due to overflow
   *
   * scrollTop:
   *  gets or sets the number of pixels that an element's content is scrolled vertically
   *
   * clientHeight:
   *  inner height of an element in pixels, includes padding but excludes borders, margins, and horizontal scrollbars
   */
  scrollIfNeeded() {
    const threshold = 25;
    const bottomDifference = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight;

    if (Math.abs(bottomDifference) >= threshold) {
      this.scrollBottom();
    }
  }


  /**
   * A method to set up a MutationObserver to watch for changes in the element.
   */
  setupObserver() {
    const observer = new MutationObserver(() => {
      this.scrollIfNeeded();
    });

    observer.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }
}
