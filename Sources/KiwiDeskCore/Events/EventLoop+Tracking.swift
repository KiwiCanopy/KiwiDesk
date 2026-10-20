import AppKit
import ApplicationServices

/// Window tracking: classify one AX window element and fold it
/// into the tracked set. Split from `EventLoop.swift` for file
/// size (§2); the reconcile funnel that drives it in bulk lives
/// in `EventLoop+Reconcile.swift`.
extension EventLoop {
    /// Adoption's one door (#913): every caller that turns an
    /// AX element into a tracked window comes through here —
    /// attach's scan, reconcile's sweep, and the window-created
    /// and deminiaturized notification arms — so the hidden
    /// refusal below is stated once instead of at each of them.
    /// A rule enforced at three of four doors is not a rule.
    /// `arrival`, an off-main read of an un-minimized window,
    /// spares every AX read below; every verdict stays here.
    func track(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        displayBounds: [CGRect]? = nil,
        arrival: ArrivalReading? = nil
    ) {
        // A hidden app's windows are on screen nowhere, so
        // adopting one would hand a tile to something the user
        // cannot see, and the next reconcile of that app would
        // take it straight back — an adopt/drop churn that
        // retiles the neighbours each way. The reachable door
        // is the create arm: an app that opens a window while
        // hidden. Whether AppKit permits that without an
        // implicit unhide was not established on device, so
        // this is defence in depth rather than a fix for an
        // observed failure — and it is why no test below
        // discriminates it (`HiddenAppWindowTests` says so in
        // its own words).
        guard !appIsHidden(pid) else { return }
        let role = arrival?.role ?? AXHelper.role(of: element)
        guard role == kAXWindowRole,
            arrival != nil || !AXHelper.isMinimized(element),
            var window = arrival?.window(pid: pid, app: app)
                ?? AXHelper.snapshot(element: element, pid: pid, app: app)
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        // One WindowServer round trip feeds every
        // classification below (layer, alpha, bounds).
        let server = FloatDetection.serverSnapshot(
            of: window.id
        )
        let layer = server.layer
        let detection: FloatDetectionSource
        let subrole: String
        // Detection judged a layer: where the server now reports
        // another, the window is judged on this one.
        if let arrival, arrival.layer == layer {
            detection = .read(arrival.autoReason)
            subrole = arrival.subrole
        } else {
            let facts = WindowFacts.read(element, role: role, layer: layer)
            detection = .facts(facts)
            subrole = facts.subrole
        }
        let displays =
            layer == nil || layer == 0
            ? []
            : displayBounds
                ?? FloatDetection.activeDisplayBounds()
        guard
            !FloatDetection.isUnbackedAuxiliary(
                role: role,
                subrole: subrole,
                layer: layer
            )
        else {
            markTransientDrop(pid: pid, id: window.id)
            return
        }
        // #309: an invisible raised-layer helper (alpha-0 or
        // fully off-screen lifecycle keepalive) never enters
        // state — tracked, it would earn a Space slot and an
        // App Bar item and read as an open app. A genuine
        // overlay caught mid fade-in is re-tracked by a later
        // reconcile pass — the one-shot re-track below is the
        // pass that is *guaranteed* to come (#675).
        guard
            !FloatDetection.isInvisibleHelper(
                layer: layer,
                alpha: server.alpha,
                bounds: server.bounds,
                displays: displays
            )
        else {
            markTransientDrop(pid: pid, id: window.id)
            return
        }
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21;
        // #448 extends this to accessory apps' raised-layer
        // command bars).
        let isAccessory = classifiesAsOverlay(pid: pid)
        guard
            !shouldIgnore(
                element,
                id: window.id,
                pid: pid,
                app: app,
                layer: layer ?? 0,
                isAccessory: isAccessory,
                tracked: false,
                titlebarButton: arrival.map {
                    $0.traits?.hasTitlebarButton == true
                }
            )
        else {
            return
        }
        // Every subrole: Orion's twin reads AXUnknown as often
        // as AXStandardWindow (#1785, device 2026-09-30). One read
        // serves the shadow rule and the App Rule's popup skip
        // (#2475).
        let traits =
            arrival.map(\.traits)
            ?? .some(shadows.traits(element, window.id))
        guard
            shadowVerdict(
                element,
                id: window.id,
                pid: pid,
                traits: traits
            ) == .window
        else { return }
        let verdict = autoFloatVerdict(
            detection,
            id: window.id,
            pid: pid,
            bundleID: app.bundleID
        )
        window.isFloating = verdict.floats
        window.isTransientOverlay = Self.isOverlay(
            verdict,
            ownProcess: Self.isOwnProcess(pid),
            structural: FloatDetection.shouldFloat(
                role: role,
                subrole: subrole,
                layer: layer ?? 0
            )
        )
        window.isRaisedLayer = (layer ?? 0) != 0
        window.hasTitlebarButton = traits??.hasTitlebarButton
        window.subrole = subrole
        // Native fullscreen suppresses the focus ring (a ring
        // around a display-filling window shows only at the
        // corners); snapshot it here, refresh on reconcile.
        window.isFullscreen = arrival?.fullscreen ?? readFullscreen(element)
        window.carriesOwnMark = tilesAsOwnWindow(pid: pid, id: window.id)
        detectedFloating[window.id] = verdict
        detectedFullscreen[window.id] = window.isFullscreen
        detectedSubroles[window.id] = subrole
        elements[pid, default: [:]][window.id] = element
        observers[pid]?.observe(window: element)
        // Remember every window's frame, and which windows carry a
        // native tab group, so a later switch (this window vanishing
        // as a sibling appears at the same frame) coalesces into a
        // re-key instead of a destroy + create (#308).
        trackedFrames[window.id] = window.frame
        offMain.noteFreshWrite(window.id)
        if arrival?.nativeTabs ?? AXHelper.hasNativeTabs(element) {
            tabCarriers.insert(window.id)
        }
        onEvent(.windowCreated(window))
    }

    /// Re-runs float detection on an already-tracked window.
    /// A window scanned mid-launch or mid-animation can report
    /// a wrong subrole once (Ghostty's quick terminal during
    /// the startup scan) and would otherwise stay misclassified
    /// until it closes. Only a changed detection verdict emits;
    /// the fold keeps a user float over it (#1810).
    // Internal (not private): also called by `handle` in
    // EventLoop+Notifications.swift.
    func recheckFloat(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t,
        app: AppRef
    ) {
        recheckFullscreen(element, id: id)
        // Beside the verdict, not from its facts: the element
        // source reads facts only where nothing forces the float.
        applySubrole(AXHelper.subrole(of: element), id: id)
        offMain.noteFreshWrite(id, [.detection])
        let verdict = autoFloatVerdict(
            .element(element, layer: FloatDetection.windowLayer(of: id)),
            id: id,
            pid: pid,
            bundleID: app.bundleID
        )
        applyFloatVerdict(verdict, id: id, pid: pid)
    }

    /// A transient overlay floats for a *structural* reason — a
    /// dialog, panel or raised layer, or a Dock-less app while a
    /// guess may float it (#2173) — never because a float rule
    /// matched, so a user-floated standard window keeps its ring
    /// while a launcher does not (#300). For a foreign window the
    /// verdict's reason says it; an own window has no such reason
    /// (#315, see `classifiesAsOverlay`), so its structure does.
    nonisolated static func isOverlay(
        _ verdict: FloatVerdict,
        ownProcess: Bool,
        structural: Bool
    ) -> Bool {
        guard !ownProcess else { return structural }
        return verdict.reason == .panel || verdict.reason == .accessoryApp
    }

    private func applyFloatVerdict(
        _ verdict: FloatVerdict,
        id: WindowID,
        pid: pid_t
    ) {
        let before = detectedFloating[id]
        // A fixed size is judged at adoption (#2070): a sheet can
        // grey the zoom button for a moment, and a recheck never
        // floats a tiled window on that reading alone — save one
        // whose verdict a changed guess forgot (#2173).
        if verdict == .floats(.fixedSize), let before, before != verdict {
            return
        }
        detectedFloating[id] = verdict
        // A changed REASON alone is stored silently: the flag
        // follows only whether the window floats.
        if before?.floats != verdict.floats {
            onEvent(.windowFloatChanged(id, isFloating: verdict.floats))
        }
        // An own window's overlay is its structure, fixed at track.
        guard !Self.isOwnProcess(pid) else { return }
        let overlay = Self.isOverlay(
            verdict,
            ownProcess: false,
            structural: false
        )
        if before.map({
            Self.isOverlay($0, ownProcess: false, structural: false)
        })
            != overlay
        {
            onEvent(.windowOverlayChanged(id, isOverlay: overlay))
        }
    }

    /// `recheckFloat` over what the off-main read found (#1933):
    /// the same two verdicts, no AX call.
    func recheckFloat(
        id: WindowID,
        pid: pid_t,
        app: AppRef,
        reading: TrackedReading
    ) {
        applyFullscreen(reading.fullscreen, id: id)
        applySubrole(reading.subrole, id: id)
        let verdict = autoFloatVerdict(
            .read(reading.autoReason),
            id: id,
            pid: pid,
            bundleID: app.bundleID
        )
        applyFloatVerdict(verdict, id: id, pid: pid)
    }

    /// Re-reads native-fullscreen state on reconcile so a
    /// green-button transition (no destroy/create pair) flips
    /// the snapshot flag and the focus ring follows. Change-only,
    /// like the float recheck above.
    private func recheckFullscreen(
        _ element: AXUIElement,
        id: WindowID
    ) {
        applyFullscreen(readFullscreen(element), id: id)
    }

    /// Emits a changed subrole (#1788): a window may drop its
    /// title bar in place as it starts presenting. An empty read
    /// is a failed one, never evidence (#1285): it files nothing.
    func applySubrole(_ subrole: String, id: WindowID) {
        guard !subrole.isEmpty, detectedSubroles[id] != subrole
        else { return }
        detectedSubroles[id] = subrole
        onEvent(.windowSubroleChanged(id, subrole: subrole))
    }

    /// Reconciles `id`'s app off the main actor for its subrole:
    /// a window crossing into covering its screen may have dropped
    /// its title bar (#1788). The whole-app read is the one that
    /// already carries the subrole off main, and a crossing is a
    /// boundary event, not a per-frame one.
    func reconcileForCoverCrossing(of id: WindowID) {
        guard let pid = trackingPID(of: id) else { return }
        reconcileOffMain(pid: pid, app: appRef(of: pid))
    }

    private func applyFullscreen(_ fullscreen: Bool, id: WindowID) {
        guard detectedFullscreen[id] != fullscreen else { return }
        detectedFullscreen[id] = fullscreen
        onEvent(
            .windowFullscreenChanged(
                id,
                isFullscreen: fullscreen
            )
        )
    }
}
