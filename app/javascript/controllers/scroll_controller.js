import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { delay: Number };

  connect() {
    this.setupObserver();
  }

  scrollBottom() {
    setTimeout(() => {
      this.element.scrollTop = this.element.scrollHeight;
    }, this.delayValue || 0);
  }

  scrollIfNeeded() {
    const threshold = 25;
    const bottomDifference = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight;

    if (Math.abs(bottomDifference) >= threshold) {
      this.scrollBottom();
    }
  }


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
