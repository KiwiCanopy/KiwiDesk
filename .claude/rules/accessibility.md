---
paths:
  - "Sources/KiwiDeskCore/AX/**"
---

# Accessibility (AX) bridge

See AGENTS.md §5 for full rationale. When editing AX code:

- AX calls are slow and can block. Never call them inside tight
  loops or layout math — snapshot state first, then compute.
- Electron/WebKit apps answer AX queries lazily (100–300 ms).
  `AXEnhancedUserInterface` is set to `true` on managed apps to
  keep their AX tree warm; do not remove it without a replacement.
- `AXObserver` callbacks arrive on the run loop of the thread that
  registered them; keep observer registration on the main thread.
