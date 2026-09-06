import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pin"]
  static values = { name: String }
  connect() {
    try { this.pinned = localStorage.getItem("runabout-theme") } catch { this.pinned = null }
    this.apply()
  }
  toggle() {
    this.pinned = this.pinned ? null : this.nameValue
    try {
      if (this.pinned) localStorage.setItem("runabout-theme", this.pinned)
      else localStorage.removeItem("runabout-theme")
    } catch { /* Theme still works when browser storage is unavailable. */ }
    this.apply()
  }
  apply() {
    const allowed = ["classic", "nemesis-blue", "voyager", "lower-decks", "lower-decks-padd", "picard"]
    const name = this.pinned || this.nameValue
    document.getElementById("lcars-theme").setAttribute("href", `/lcars/${allowed.includes(name) ? name : "classic"}.css`)
    this.pinTarget.textContent = this.pinned ? "Unpin theme" : "Pin theme"
    this.pinTarget.setAttribute("aria-pressed", String(Boolean(this.pinned)))
  }
}
