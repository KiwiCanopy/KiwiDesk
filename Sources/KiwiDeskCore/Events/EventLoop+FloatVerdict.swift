import AppKit
import ApplicationServices

/// The automatic float verdict (#1810): the force-float reason
/// first, else detection over one window's `WindowFacts` (#1883).
extension EventLoop {
    /// Where detection's half of a verdict comes from: facts
    /// already read, the element — read through `WindowFacts` only
    /// where nothing forces the float — or what an off-main read
    /// found (#1933).
    enum FloatDetectionSource {
        case facts(WindowFacts)
        case element(AXUIElement, layer: Int?)
        case read(AutoFloatReason?)
    }

    /// The automatic verdict for one tracked window (#1810) — the
    /// one composition `track` and `recheckFloat` both take.
    func autoFloatVerdict(
        _ source: FloatDetectionSource,
        id: WindowID,
        pid: pid_t,
        bundleID: String?
    ) -> FloatVerdict {
        Self.composeVerdict(
            source,
            pid: pid,
            activationPolicy: policy(of: pid),
            tilesAsOwnWindow: tilesAsOwnWindow(pid: pid, id: id),
            bundleID: bundleID,
            rules: floatRules
        )
    }

    /// `autoFloatVerdict` over the app's policy and the own-window
    /// mark as read, pure where the source is: a forced float asks
    /// detection nothing (#1883 replays dumps through it).
    nonisolated static func composeVerdict(
        _ source: FloatDetectionSource,
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        tilesAsOwnWindow: Bool,
        bundleID: String?,
        rules: FloatRules
    ) -> FloatVerdict {
        if let forced = forceFloatReason(
            pid: pid,
            activationPolicy: activationPolicy,
            tilesAsOwnWindow: tilesAsOwnWindow
        ) {
            return .floats(forced)
        }
        let facts: WindowFacts
        switch source {
        case .facts(let read):
            facts = read
        case .element(let element, let layer):
            facts = WindowFacts.read(element, layer: layer)
        case .read(let reason):
            return FloatVerdict(reason)
        }
        return FloatVerdict(
            FloatDetection.autoFloatReason(
                facts,
                bundleID: bundleID,
                rules: rules
            )
        )
    }
}
