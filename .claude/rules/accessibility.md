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
- **Never assume an installed observer delivers (#675).**
  `AXObserverAddNotification` can refuse a fresh-launch app whose
  AX tree is not ready, and the refusal used to be discarded —
  the observer then sat installed and deaf (no `windowCreated`,
  no `focusedWindowChanged`) while its non-nil `observers[pid]`
  entry blocked any re-attach, which is how a Spotlight-launched
  app's windows were never adopted. `AXApplicationObserver`
  records the failed adds; every reconcile touchpoint and the
  adoption-heal sweep call `repairRegistration()`, and the sweep
  (`EventLoop.healSweep`) is the pass *guaranteed* to come —
  census-gated so a healthy tick costs one WindowServer snapshot
  and no AX. `AdoptionHealTests` pins the gate and both repair
  funnels; `AdoptionHealScheduleTests` pins the scheduled tasks.
  Nothing machine-checks that `KiwiCore.start()` still calls
  `scheduleAdoptionHeal()` — the same unpinnable link as the
  `scheduleStartupSweep()` bullet below — so do not drop or
  re-time that call without adding the pin and re-deriving the
  `docs/accepted-limitations.md` heal-latency row.
- **The startup scan may skip the AX warmup only for an app the
  WindowServer reports windowless, and only because a following
  reconcile warms whatever was skipped (#662).** Three links
  carry that promise, guarded two-and-a-half ways: the skip
  gate and the reconcile-warms retry are pinned by
  `StartupWarmupSkipTests`, and the scheduled sweep's task
  actually running a `reconcileAll` is pinned by
  `StartupSweepTests` — but nothing machine-checks that
  `start()` still *calls* `scheduleStartupSweep()`, so do not
  drop or re-time that call without adding the pin and
  re-deriving the ceiling `docs/accepted-limitations.md`
  accepts for the user-visible residue.
