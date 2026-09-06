import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["elapsed", "seek", "error"]
  static values = { position: Number, captured: String, rate: Number, playing: Boolean, duration: Number }
  connect() {
    this.protectScrub = (event) => {
      if (this.scrubbing && event.target.getAttribute("target") === "now-playing") event.preventDefault()
    }
    document.addEventListener("turbo:before-stream-render", this.protectScrub)
    this.tick()
    this.timer = setInterval(() => this.tick(), 250)
  }
  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("turbo:before-stream-render", this.protectScrub)
  }
  tick() {
    if (this.scrubbing) return
    const age = Math.max(0, (Date.now() - Date.parse(this.capturedValue)) / 1000) || 0
    // A dead watcher must not leave progress advancing indefinitely.
    const position = Math.max(0, Math.min(this.durationValue, this.positionValue + (this.playingValue ? Math.min(age, 20) * this.rateValue : 0)))
    this.seekTarget.value = position
    this.elapsedTarget.textContent = this.format(position)
  }
  format(value) {
    const seconds = Math.floor(value)
    return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`
  }
  scrub(event) {
    this.scrubbing = true
    this.elapsedTarget.textContent = this.format(Number(event.target.value))
  }
  commit(event) {
    event.target.form.requestSubmit()
    this.scrubbing = false
  }
  async command(event) {
    event.preventDefault()
    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(event.target.action, { method: "POST", body: new FormData(event.target), headers: token ? { "X-CSRF-Token": token } : {} })
      if (!response.ok || response.redirected) throw new Error("Control unavailable. The player may have changed; try again.")
      this.errorTarget.textContent = "Command queued."
      this.errorTarget.hidden = false
    } catch (error) {
      this.errorTarget.textContent = error.message
      this.errorTarget.hidden = false
    }
  }
}
