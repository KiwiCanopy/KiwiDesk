import Foundation

/// A screen change composed the built-in Standard because no
/// saved profile is for this many screens (#3646). Structure only:
/// the GUI narrates it.
public struct StandardFallback: Sendable, Equatable {
    public let screenCount: Int

    public init(screenCount: Int) {
        self.screenCount = screenCount
    }
}

/// Fired when a screen change composed the Standard
/// (`KiwiCore.onStandardFallback`).
public typealias StandardFallbackComposed =
    @MainActor (StandardFallback) -> Void

extension KiwiCore {
    /// The profile choice of a change in the connected screens,
    /// announcing a Standard it composed where `announcing` — the
    /// first screen report and a settled count change. A same-count
    /// re-report (a wake, a resolution change) passes false, and
    /// the re-choice after a profile edit, a delete or a restore
    /// calls `handleMonitorChange` itself: no screen arrived, so
    /// they announce nothing (#3646).
    func handleScreenChange(announcing: Bool) {
        let fallback = handleMonitorChange()
        guard announcing, let fallback else { return }
        onStandardFallback(fallback)
    }
}
