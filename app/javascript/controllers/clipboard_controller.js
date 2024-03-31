import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source"]
  connect() {
  }

  copy() {
    const text = this.sourceTarget.innerText
    navigator.clipboard.writeText(text)
      .then(() => {
        console.log('Text copied to clipboard');
      })
      .catch((error) => {
        console.error('Failed to copy text to clipboard:', error);
      });
  }
}
