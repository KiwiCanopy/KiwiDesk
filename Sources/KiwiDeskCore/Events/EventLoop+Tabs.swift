import AppKit
import ApplicationServices

/// Native-tab coalescing (#308). macOS native tabs are separate
/// `NSWindow`s sharing one on-screen frame, only the active one
/// visible to AX at a time, each with its own `CGWindowID`. A tab
/// switch (or an active-tab close with a sibling left, or a new tab
/// opening active) therefore reaches reconcile as one `hasTabGroup`
/// window vanishing while another appears at the same frame. This
/// extension turns that pair into a single `.windowRekeyed` instead
/// of a destroy + create, so the tab group keeps its one layout slot,
/// focus, and weights.
extension EventLoop {
    /// Resolve the vanished/appeared diff for one reconcile pass:
    /// coalesce native-tab switches into re-keys, then track the
    /// genuinely new windows and destroy the genuinely closed ones.
    /// `appeared` are live windows not yet tracked (their `track`
    /// was deferred so a switch is not first emitted as a create).
    func reconcileTabsAndSweep(
        pid: pid_t,
        app: AppRef,
        appeared: [(element: AXUIElement, id: WindowID)],
        live: Set<WindowID>,
        minimized: Set<WindowID>
    ) {
        let vanishedIDs = elements[pid, default: [:]].keys
            .filter { !live.contains($0) }
        let rekeys = TabReconciler.rekeys(
            vanished: vanishedIDs.compactMap { id in
                tabFrames[id].map {
                    TabWindow(id: id, frame: $0, hasTabGroup: true)
                }
            },
            appeared: appeared.compactMap { pair in
                guard AXHelper.hasNativeTabs(pair.element) else {
                    return nil
                }
                return TabWindow(
                    id: pair.id,
                    frame: AXHelper.frame(of: pair.element),
                    hasTabGroup: true
                )
            }
        )
        var elementByID = Dictionary(
            uniqueKeysWithValues: appeared.map { ($0.id, $0.element) }
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
            tabFrames[id] = nil
            onEvent(
                .windowDestroyed(
                    id,
                    wasMinimized: minimized.contains(id)
                )
            )
        }
    }

    /// Move the tracked AX registration from the vanished tab to the
    /// new active tab and emit the re-key. The group's float verdict
    /// carries over (same window, same tiling status); the new
    /// element is observed so its later move/resize/title flow.
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
        tabFrames[from] = nil
        tabFrames[to] = AXHelper.frame(of: element)
        observers[pid]?.observe(window: element)
        onEvent(.windowRekeyed(from, to))
    }
}
