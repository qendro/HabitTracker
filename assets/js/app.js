import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
const PREFIX = "health-journal:draft:"
const expiry = 24 * 60 * 60 * 1000
function clearDrafts() {
  try { Object.keys(sessionStorage).filter(k => k.startsWith(PREFIX)).forEach(k => sessionStorage.removeItem(k)) } catch {}
}
if (document.body.dataset.journalUser === "guest") clearDrafts()
const authChannel = typeof BroadcastChannel === "function" ? new BroadcastChannel("health-journal-auth") : null
if (authChannel) authChannel.onmessage = e => { if (e.data === "logout") clearDrafts() }
try {
  Object.keys(sessionStorage).filter(k => k.startsWith(PREFIX)).forEach(k => {
    try { if (Date.now() - JSON.parse(sessionStorage.getItem(k)).at > expiry) sessionStorage.removeItem(k) }
    catch { sessionStorage.removeItem(k) }
  })
} catch {}
window.addEventListener("click", e => {
  if (e.target.closest("[data-logout]")) queueMicrotask(() => {
    if (!e.journalNavigationCancelled) { clearDrafts(); authChannel?.postMessage("logout") }
  })
}, true)
const Draft = {
  mounted() {
    this.key = PREFIX + this.el.dataset.draftKey
    this.dirty = false
    this.handleEvent("draft-saved", () => { this.dirty = false; try { sessionStorage.removeItem(this.key) } catch {} })
    this.store = () => {
      this.dirty = true
      const values = {}
      new FormData(this.el).forEach((value, key) => {
        if (typeof value === "string" && key.startsWith("entry[")) values[key] = value
      })
      try { sessionStorage.setItem(this.key, JSON.stringify({at: Date.now(), values})) }
      catch { document.getElementById("draft-status").textContent = "Draft storage unavailable. Keep this tab open until the server confirms saving." }
    }
    this.restore = () => {
      try {
        const draft = JSON.parse(sessionStorage.getItem(this.key))
        if (!draft) return
        if (Date.now() - draft.at > expiry) { sessionStorage.removeItem(this.key); return }
        this.pushEvent("restore-draft", {values: draft.values})
        this.dirty = true
        document.getElementById("draft-status").textContent = "Text draft restored. Review it before saving; reselect unfinished photos."
      } catch { try { sessionStorage.removeItem(this.key) } catch {} }
    }
    this.input = () => this.store()
    this.beforeUnload = e => { if (this.dirty) { e.preventDefault(); e.returnValue = "" } }
    this.navigate = e => {
      if (this.dirty && e.target.closest("a[href]") && !confirm("Leave with unsaved changes? A text draft will remain in this tab.")) {
        e.journalNavigationCancelled = true; e.preventDefault(); e.stopImmediatePropagation()
      }
    }
    this.el.addEventListener("input", this.input)
    this.el.addEventListener("change", this.input)
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("click", this.navigate, true)
    this.restore()
  },
  destroyed() {
    this.el.removeEventListener("input", this.input)
    this.el.removeEventListener("change", this.input)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("click", this.navigate, true)
  }
}
const csrf = document.querySelector("meta[name=csrf-token]").content
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrf}, hooks: {Draft, Connection: {
  disconnected() { status.hidden = false },
  reconnected() { status.hidden = true },
  mounted() { status.hidden = navigator.onLine }
}}})
const status = document.getElementById("connection-status")
liveSocket.getSocket().onClose(() => status.hidden = false)
liveSocket.getSocket().onError(() => status.hidden = false)
liveSocket.getSocket().onOpen(() => status.hidden = true)
window.addEventListener("offline", () => status.hidden = false)
window.addEventListener("online", () => { status.hidden = liveSocket.isConnected() })
liveSocket.connect()
// No service worker: authenticated pages, exports and photos never enter a Cache API cache.
