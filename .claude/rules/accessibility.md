---
paths:
  - "Sources/KiwiDeskCore/AX/**"
---

# Accessibility (AX) bridge

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing AX code:

- AX calls are slow and can block. Never call them inside tight
  loops or layout math — snapshot state first, then compute.
- Electron/WebKit apps answer AX queries lazily (100–300 ms).
  `AXEnhancedUserInterface` is set to `true` on managed apps to
  keep their AX tree warm; do not remove it without a replacement.
- `AXObserver` callbacks arrive on the run loop of the thread that
  registered them; keep observer registration on the main thread.
- **Keep the boot's process-global AX messaging timeout.**
  `EventLoop.start()` bounds every AX message at ~1 s
  (`AXHelper.setGlobalMessagingTimeout`) before its first
  per-app call — without the bound, an unresponsive app costs
  the ~6 s system default per call, and the scan's serial
  main-thread calls turned one stopped helper into a ~60 s boot
  (#672). `StartupAXTimeoutTests` pins the wiring and the
  value. Red-prove the stall itself on-device (`kill -STOP` any
  GUI app, then boot), never with a real SIGSTOP in CI —
  tests.md's hang-guard rule.
- **The startup scan may skip the AX warmup only for an app the
  WindowServer reports windowless, and only because a following
  reconcile warms whatever was skipped (#662).** A reconcile of
  a regular app must keep retrying `warmAccessibilityTree`;
  `StartupWarmupSkipTests` is the guard that reds when either
  half of that promise breaks. The user-visible residue — a
  windowless app's tree materializes up to ~1 s late — is
  accepted in `docs/accepted-limitations.md`.
