import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import hljs from "highlight.js"

// Connects to data-controller="markdown-text"
export default class extends Controller {
  static values = { updated: String }

  // Anytime `updated` value changes, this function gets called
  updatedValueChanged() {
    console.log("=== RUNNING MarkdownTextController#updatedValueChanged ===")
    const markdownText = this.element.innerText || ""
    const html = marked.parse(markdownText)
    console.dir(html)

    this.element.innerHTML = html
    this.element.querySelectorAll("pre").forEach((block) => {
      hljs.highlightElement(block)
    })

    window.scrollTo(0, document.documentElement.scrollHeight);
  }
}
