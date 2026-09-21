import ApplicationServices

/// Which window an AX notification is about — the tracked map
/// first, the app second (#1084), shared by every notification
/// arm.
extension EventLoop {
    /// How the tracked map answers for an element (#1084).
    enum TrackedMatch: Equatable {
        /// Exactly one tracked id carries this element.
        case one(WindowID)
        /// No tracked window carries it.
        case none
        /// Two or more ids carry it — only the app can settle
        /// which (#1084, architect review): the map is keyed by
        /// id, so nothing structurally forbids two ids pointing
        /// at one element, and a Dictionary's iteration order is
        /// undefined — so `first(where:)` over a duplicate is a
        /// COIN FLIP per notification, and a wrong id moves the
        /// wrong window. Device-observed 2026-08-29 while
        /// merging Finder tabs: windows moved sideways and an
        /// unrelated app minimized, intermittently.
        case ambiguous
    }

    /// The tracked map's answer for `element`: an in-process
    /// `CFEqual` scan over that app's windows and no IPC at all.
    ///
    /// **It needs no invalidation, and that is why it is the
    /// map rather than a cache of its own.** `elements` is
    /// dropped per pid on app termination, per window on a
    /// vanish, and re-keyed (old key removed first) on a native
    /// tab switch — so it holds at most one id per element and
    /// never a stale one. A destroyed or unknown element simply
    /// fails to match, which is also what makes this safe
    /// against the #308 recycled-id hazard: a recycled id
    /// arrives on a NEW element, which cannot `CFEqual` the old
    /// one.
    func trackedMatch(
        of element: AXUIElement,
        pid: pid_t
    ) -> TrackedMatch {
        let matches = elements[pid, default: [:]]
            .filter { CFEqual($1, element) }
        switch matches.count {
        case 0: return .none
        case 1: return matches.first.map { .one($0.key) } ?? .none
        default: return .ambiguous
        }
    }

    /// The window an AX notification is about — from the
    /// TRACKED map first, and only then by asking the app
    /// (#1084).
    ///
    /// `AXHelper.windowID(of:)` is `_AXUIElementGetWindow`, a
    /// synchronous MIG round-trip into the other process. It
    /// costs 1–20 ms when that app is idle and unboundedly more
    /// when it is busy, and it runs on the main thread — which
    /// is the thread the `CADisplayLink` callback is delivered
    /// on. So paying it per notification starved our own frame
    /// clock: device capture 2026-08-28 measured 42 stalls in
    /// ten seconds of held resize, up to 607 ms (6–30 frames
    /// never delivered), with ~37% of main-thread samples
    /// blocked in that call. Every applied frame emits a
    /// move/resize notification, so a resize funds its own
    /// starvation.
    ///
    /// The ask stays as the fallback, and stays SECOND: it is
    /// the only answer for a window not yet adopted, the only
    /// thing that can tell us a brand-new window's id, and the
    /// one party that can settle an ambiguous match — two
    /// matches costs one round-trip, the same price this path
    /// paid for EVERY notification before.
    ///
    /// What the map does NOT carry is liveness: asking filtered
    /// destroyed elements for free, since they answer nothing,
    /// while the map still names a window whose entry the
    /// destroy sweep has not reached. Every arm on this route
    /// therefore reads the element off the main actor and drops
    /// a dead one at delivery — a `.zero` frame for the
    /// move/resize and focus arms, a failed title copy for the
    /// title arm (#1088; `EventLoop+FocusReport`,
    /// `EventLoop+TitleReport`).
    ///
    /// `arm` names the notification in the ask's log line, so a
    /// device trace tells the blocking path from the map.
    func windowID(
        of element: AXUIElement,
        pid: pid_t,
        arm: String
    ) -> WindowID? {
        switch trackedMatch(of: element, pid: pid) {
        case .one(let id):
            return id
        case .none:
            return askWindowID(
                element,
                pid: pid,
                arm: arm,
                reason: "untracked"
            )
        case .ambiguous:
            return askWindowID(
                element,
                pid: pid,
                arm: arm,
                reason: "ambiguous"
            )
        }
    }

    /// The map's answer for an arm that acts only on a TRACKED
    /// window, so a MISS drops rather than asks (#1088): the
    /// title arm, registered per window at `track`, so a miss is
    /// a released window; and the destroy/minimize arm, whose
    /// own `elements[pid]?[id] != nil` gate an asked id could
    /// pass only if the map held it under a non-equal element,
    /// which the map's invariant above rules out. An ambiguous
    /// match still asks: both its ids are tracked.
    func trackedWindowID(
        of element: AXUIElement,
        pid: pid_t,
        arm: String
    ) -> WindowID? {
        switch trackedMatch(of: element, pid: pid) {
        case .one(let id):
            return id
        case .none:
            return nil
        case .ambiguous:
            return askWindowID(
                element,
                pid: pid,
                arm: arm,
                reason: "ambiguous"
            )
        }
    }

    /// The round-trip into the app, logged so a device trace
    /// can tell the blocking path from the map (#1088).
    func askWindowID(
        _ element: AXUIElement,
        pid: pid_t,
        arm: String,
        reason: String
    ) -> WindowID? {
        let id = resolveWindowID(element)
        onLog(
            "notify: \(arm) asked pid \(pid) (\(reason)) → "
                + (id.map { "w\($0.raw)" } ?? "no answer")
        )
        return id
    }
}
