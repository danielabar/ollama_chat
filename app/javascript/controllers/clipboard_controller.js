import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source", "button"]
  connect() {
  }

  copy() {
    const text = this.sourceTarget.innerText
    navigator.clipboard.writeText(text)
      .then(() => {
        console.log('Text copied to clipboard');
        this.buttonTarget.textContent = 'Copied';
        setTimeout(() => {
          this.buttonTarget.textContent = 'Copy';
        }, 2000);
      })
      .catch((error) => {
        console.error('Failed to copy text to clipboard:', error);
      });
  }
}
