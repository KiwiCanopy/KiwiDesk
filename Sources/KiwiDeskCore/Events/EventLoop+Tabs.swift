import AppKit
import ApplicationServices

/// Native-tab coalescing (#308). macOS native tabs are separate
/// `NSWindow`s sharing one on-screen frame, only the active one
/// visible to AX at a time, each with its own `CGWindowID`. A tab
/// switch (or an active-tab close with a sibling left, or a new tab
/// opening active) therefore reaches reconcile as one window
/// vanishing while another appears at the same frame. This extension
/// turns that pair into a single `.windowRekeyed` instead of a
/// destroy + create, so the tab group keeps its one layout slot,
/// focus, and weights.
///
/// Timing assumption: coalescing commits within a single reconcile
/// pass — the vanished tab and the appearing sibling must both be
/// observable against one `AXHelper.windows(pid:)` snapshot. In
/// practice macOS activates the promoted tab before delivering the
/// close, so the sibling is already live when the destroy's reconcile
/// runs. If it is not, the pair falls back to a destroy + create (the
/// pre-#308 behavior) — a missed merge, never a wrong one.
extension EventLoop {
    /// Grace window after a native-Space change during which no
    /// reconcile coalesces tabs — a genuine tab switch within it
    /// falls back to destroy + create (self-healing) — AND the
    /// removal-distrust gate stands down (#1157): the census
    /// double-exposes both Desktops while the compositor settles
    /// (#1023), so retuning this for tab reasons retunes the
    /// gate's stand-down too. The gate's expected-absence arms
    /// (#1145, #1272) read their own signals, never this one.
    static let spaceSwitchCoalesceGrace: TimeInterval = 0.75

    /// The one derivation of "inside that grace" — the tab
    /// coalescer and the distrust gate must age the same stamp.
    func isWithinSpaceSwitchGrace(now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastDesktopChange)
            < Self.spaceSwitchCoalesceGrace
    }

    /// True if the app has a tracked native-tab carrier. Used to
    /// route a *non*-carrier window's create/destroy through reconcile
    /// at the 1↔2 tab boundary, where the single remaining/promoted
    /// tab exposes no `AXTabGroup` of its own yet (#308).
    func appHasTabCarrier(pid: pid_t) -> Bool {
        elements[pid, default: [:]].keys.contains {
            tabCarriers.contains($0)
        }
    }

    /// Resolve the vanished/appeared diff for one reconcile pass:
    /// coalesce native-tab switches into re-keys, then track the
    /// genuinely new windows and destroy the genuinely closed ones.
    /// `appeared` are live windows not yet tracked (their `track` was
    /// deferred so a switch is not first emitted as a create).
    /// `coalesceTabs` is false on a native-space switch, where same-app
    /// windows across spaces tile to identical frames and must not
    /// merge (#308 review).
    func reconcileTabsAndSweep(
        pid: pid_t,
        app: AppRef,
        appeared: [(element: AXUIElement, id: WindowID)],
        live: Set<WindowID>,
        minimized: Set<WindowID>,
        coalesceTabs: Bool,
        hidden: Bool = false
    ) {
        let vanishedIDs = elements[pid, default: [:]].keys
            .filter { !live.contains($0) }
        let rekeys =
            coalesceTabs
            ? TabReconciler.rekeys(
                vanished: rekeyCandidates(vanishedIDs, minimized),
                appeared: appeared.map(appearedTab)
            )
            : []
        var elementByID = Dictionary(
            appeared.map { ($0.id, $0.element) },
            uniquingKeysWith: { first, _ in first }
        )
        var consumed: Set<WindowID> = []
        for rekey in rekeys {
            guard let element = elementByID[rekey.to] else { continue }
            applyTabRekey(
                from: rekey.from,
                to: rekey.to,
                element: element,
                pid: pid
            )
            consumed.insert(rekey.from)
            elementByID[rekey.to] = nil
        }
        // Genuine new windows: track normally (emits windowCreated).
        let displayBounds = FloatDetection.activeDisplayBounds()
        for pair in appeared.sorted(by: { $0.id.raw < $1.id.raw })
        where elementByID[pair.id] != nil {
            track(
                pair.element,
                pid: pid,
                app: app,
                displayBounds: displayBounds
            )
        }
        // A window back in the AX list ends its distrust episode
        // (#1157), so a later absence is refused — and logged —
        // afresh.
        removalDistrusted = removalDistrusted.filter {
            !live.contains($0.key)
        }
        // Genuine closes: emit the destroy the eager path deferred.
        // A candidate is checked against ONE census per sweep; a
        // window the compositor still shows was not closed
        // (#1157 — the exempt arms are accessibility.md's).
        let switchGrace = isWithinSpaceSwitchGrace()
        var onScreen: Set<WindowID>?
        for id in vanishedIDs.sorted(by: { $0.raw < $1.raw })
        where !consumed.contains(id) {
            let census = {
                let read =
                    onScreen
                    ?? self.onScreenNormalWindowIDs()[
                        pid,
                        default: []
                    ]
                onScreen = read
                return read
            }
            // A hide is a total answer about the app (#913), and
            // a minimize is the window's own verdict: neither is
            // a vanish an expected-absence arm could explain
            // (#1145, #1272).
            if !hidden, !minimized.contains(id),
                refusesExpectedRemoval(
                    id,
                    pid: pid,
                    app: app,
                    census: census
                )
            {
                continue
            }
            if !hidden, !switchGrace, !minimized.contains(id),
                census().contains(id)
            {
                refuseRemoval(id, pid: pid, app: app)
                continue
            }
            releaseWindowRegistration(id, pid: pid)
            // A hidden app's whole sweep is a hide (#913):
            // the windows are not gone, their app is, so they
            // must not be reported as closed and must not move
            // the user's focus.
            //
            // The hidden path passes an empty `minimized`, so
            // the two cannot both be true here — but that is
            // this sweep's ignorance, not a fact about the
            // window. A window whose miniaturize notification
            // was dropped, and whose app then hides, is parked
            // AND reported hidden, so it files no
            // most-recently-minimized record (#673). Left
            // alone: separating them means asking AX which
            // windows are minimized, which is the read this
            // path exists to avoid, to mend a record its own
            // docs call best-effort.
            onEvent(
                hidden
                    ? .windowHidden(id)
                    : .windowDestroyed(
                        id,
                        wasMinimized: minimized.contains(id)
                    )
            )
        }
    }

    /// Vanished windows eligible to be re-keyed. Minimized windows are
    /// excluded — a minimize is not a tab close (`TabReconciler`'s
    /// precondition) — but they stay in the sweep so they still emit a
    /// destroy. A window with no remembered frame can't be matched.
    ///
    /// The remembered frame can lag by one in-flight read (#618):
    /// move/resize frames land a hop after their notification, so
    /// a tab switch racing a read compares against the frame one
    /// move ago and can miss the coalesce. Accepted — the miss
    /// degrades to the destroy+create fallback this file already
    /// documents as self-healing, the overlap needs the switch to
    /// land inside a read's flight, and the alternative (draining
    /// the pid's reads before the sweep) blocks the main actor on
    /// the stalled-app IPC #618 exists to move off it.
    private func rekeyCandidates(
        _ vanishedIDs: [WindowID],
        _ minimized: Set<WindowID>
    ) -> [TabWindow] {
        vanishedIDs.compactMap { id in
            guard !minimized.contains(id),
                let frame = trackedFrames[id]
            else { return nil }
            return TabWindow(
                id: id,
                frame: frame,
                hasTabGroup: tabCarriers.contains(id)
            )
        }
    }

    private func appearedTab(
        _ pair: (element: AXUIElement, id: WindowID)
    ) -> TabWindow {
        TabWindow(
            id: pair.id,
            frame: AXHelper.frame(of: pair.element),
            hasTabGroup: AXHelper.hasNativeTabs(pair.element)
        )
    }

    /// Move the tracked AX registration from the vanished tab to the
    /// new active tab and emit the re-key. The group's float verdict
    /// carries over (same window, same tiling status); carrier status
    /// is re-derived (at the 2→1 boundary the survivor may expose no
    /// tab group); the new element is observed so its later
    /// move/resize/title flow.
    private func applyTabRekey(
        from: WindowID,
        to: WindowID,
        element: AXUIElement,
        pid: pid_t
    ) {
        // Read the migrating verdicts BEFORE the release clears
        // the `from` side.
        let floating = detectedFloating[from]
        let fullscreen = detectedFullscreen[from]
        releaseWindowRegistration(from, pid: pid)
        elements[pid, default: [:]][to] = element
        detectedFloating[to] = floating
        detectedFullscreen[to] = fullscreen
        trackedFrames[to] = AXHelper.frame(of: element)
        if AXHelper.hasNativeTabs(element) {
            tabCarriers.insert(to)
        }
        observers[pid]?.observe(window: element)
        // The frame/animation effect caches (FrameApplier, animation)
        // keep the old id and self-heal on the next animation end —
        // exactly as the destroy path leaves them, so no migration is
        // needed here (#308 review).
        onEvent(.windowRekeyed(from, to))
    }
}
