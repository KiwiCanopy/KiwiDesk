import AppKit
import ApplicationServices

/// The bulk re-sync — every observed app against its live AX
/// window list — and the WindowServer gate that keeps it off
/// the apps with nothing to say (#1037). Split from
/// `EventLoop+Apps.swift` at the §2.1 ceiling when the gate
/// joined it.
extension EventLoop {
    /// Re-syncs every attached app against its live AX window
    /// list: the Desktop switch's pass and the config reload's.
    /// The pass one second after boot is `beginSweep`'s own
    /// (#801) — chunked, and deliberately NOT gated as below:
    /// its warm is the #662 promise to apps the boot prefilter
    /// called windowless, which show nothing on any Desktop.
    ///
    /// **Gated by one WindowServer census, never by AX
    /// (#1037).** The pass used to ask every observed app for
    /// its window list, and an app not servicing AX — an
    /// App-Napped one whose windows all sit on other Desktops,
    /// or a headless agent — blocks the main actor until the
    /// process-wide messaging timeout fires. Device-traced
    /// 2026-08-26: eight such apps × ~1 s, in series, on EVERY
    /// Desktop switch, an empty target Desktop included; the
    /// arrived window's ring, retile and raise all queued
    /// behind them. The census (~1 ms, no AX) already answers
    /// for those apps: one that tracks no window and shows no
    /// window has nothing to remove and nothing to adopt, so
    /// asking it is pure cost. `reconcileAllTargets` is the
    /// one copy of that rule, and it is what
    /// `ReconcileAllPrefilterTests` pins.
    ///
    /// The gate skips whole apps; it never cuts a reconcile
    /// short. An app the gate reaches is read in full — the
    /// sweep in `reconcile` derives destroys from the live
    /// list, and accessibility.md's abort-before-sweep
    /// obligation stands.
    ///
    /// What the census cannot see at the moment the switch
    /// notification fires: a window that has not composited
    /// yet (#1023 measured the moved window landing ~130–300 ms
    /// after the pointer write). `reconcileOnScreenArrivals`
    /// is the answer, run from the Desktop settle
    /// (`settleAfterDesktopSwitch` owns its delay).
    public func reconcileAll() {
        let signposter = BootSignpost.signposter
        let span = signposter.beginInterval("reconcileAll")
        defer { signposter.endInterval("reconcileAll", span) }
        // Rules can detach an already-observed app or make a
        // formerly ignored app observable. Synchronize that
        // app-level boundary without reading ignored AX trees.
        // A fresh attach defers its scan to the gated loop
        // below rather than reading the list twice (#672); one
        // the gate skips shows nothing, and is scanned by the
        // first pass that reaches it.
        for app in runningApplications() {
            syncObservation(for: app, scanWindowsAtAttach: false)
        }
        // Before the census: `loadConfig` runs this pass ahead
        // of the scan, with nothing observed — a WindowServer
        // read there would be pure cost, and one every suite
        // driving `loadConfig` inherits (review).
        let observed = Array(observers.keys)
        guard !observed.isEmpty else { return }
        let census = onScreenNormalWindowIDs()
        let targets = Self.reconcileAllTargets(
            observed: observed,
            census: census,
            tracks: { !(elements[$0]?.isEmpty ?? true) }
        )
        // Suppress native-tab coalescing here: a native-space switch
        // presents the departed space's windows as vanished and the
        // arrived space's as appeared in one pass, and same-app
        // windows tile to identical frames — they would false-merge
        // into a re-key (#308 review). Genuine switches coalesce via
        // the per-window reconciles the AX notifications drive.
        for pid in targets {
            reconcile(pid: pid, app: AppRef(pid: pid), coalesceTabs: false)
        }
        let skipped = observed.count - targets.count
        if skipped > 0 {
            onLog(
                "reconcileAll: \(skipped) app(s) track nothing and "
                    + "show nothing — not asked"
            )
        }
    }

    /// Which observed apps a bulk pass reads: those tracking a
    /// window (a departure to remove, a float verdict to
    /// re-check) or showing one on screen (an arrival to
    /// adopt). An app doing neither is skipped — it has nothing
    /// the pass could change, and if it is not answering AX the
    /// read costs the whole messaging timeout. Order is the
    /// caller's, preserved.
    ///
    /// Pure, so the gate is assertable without a WindowServer.
    static func reconcileAllTargets(
        observed: [pid_t],
        census: [pid_t: Set<WindowID>],
        tracks: (pid_t) -> Bool
    ) -> [pid_t] {
        observed.filter { pid in
            tracks(pid) || !(census[pid]?.isEmpty ?? true)
        }
    }

    /// The settle's arrival sweep (#1037): one fresh census,
    /// and a reconcile for each observed app that shows a
    /// window the loop does not track. It closes the gap the
    /// gate above opens — the switch notification can beat the
    /// compositor, so the pass at the notification may have
    /// skipped an app whose window was still landing.
    ///
    /// `healSweep`'s gate without its ledger: the heal quiets an
    /// id that fails to adopt, which is right for a permanent
    /// mismatch (an ignored panel) and wrong for a window whose
    /// app has simply not re-listed it yet — that quieting is
    /// exactly what left a moved window unmanaged in the #1023
    /// trace. Every app this reads is showing a window, so it
    /// is not napping — a hung one still costs its timeout,
    /// once per settle, as it did before. An app with no observer
    /// stays the heal's: attaching is its funnel. The
    /// membership read (`ids.subtracting(tracked)`, ids never a
    /// count — the argument is on `onScreenNormalWindowIDs`) is
    /// a deliberate copy of the heal's, kept beside its own
    /// ledger decision rather than shared, because the two
    /// diverge exactly there.
    ///
    /// A follow onto a hidden Desktop has a second adopter: the
    /// 700 ms per-pid reap in `departEagerly`, which stays for
    /// the window that composites after this sweep's census and
    /// for a switch that was accepted but never notified — no
    /// notification, no settle, no sweep.
    func reconcileOnScreenArrivals() {
        guard isRunning else { return }
        let census = onScreenNormalWindowIDs()
        for (pid, ids) in census where observers[pid] != nil {
            let tracked = Set(elements[pid, default: [:]].keys)
            guard !ids.subtracting(tracked).isEmpty else { continue }
            reconcile(pid: pid, app: AppRef(pid: pid), coalesceTabs: false)
        }
    }
}
