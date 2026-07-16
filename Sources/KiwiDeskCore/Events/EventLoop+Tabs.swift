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
        coalesceTabs: Bool
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
        for pair in appeared.sorted(by: { $0.id.raw < $1.id.raw })
        where elementByID[pair.id] != nil {
            track(pair.element, pid: pid, app: app)
        }
        // Genuine closes: emit the destroy the eager path deferred.
        for id in vanishedIDs.sorted(by: { $0.raw < $1.raw })
        where !consumed.contains(id) {
            elements[pid]?[id] = nil
            detectedFloating[id] = nil
            ignorePending.remove(id)
            trackedFrames[id] = nil
            tabCarriers.remove(id)
            onEvent(
                .windowDestroyed(
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
        elements[pid]?[from] = nil
        elements[pid, default: [:]][to] = element
        detectedFloating[to] = detectedFloating[from]
        detectedFloating[from] = nil
        ignorePending.remove(from)
        trackedFrames[from] = nil
        trackedFrames[to] = AXHelper.frame(of: element)
        tabCarriers.remove(from)
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
