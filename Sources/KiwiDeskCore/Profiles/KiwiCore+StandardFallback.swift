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
    /// The profile choice of a change in the connected screens —
    /// the first screen report and a settled count change — which
    /// announces a Standard it composed. The other callers of
    /// `handleMonitorChange` re-choose after a profile edit, a
    /// delete or a restore; no screen arrived, so they announce
    /// nothing (#3646).
    func handleScreenChange() {
        guard let fallback = handleMonitorChange() else { return }
        onStandardFallback(fallback)
    }
}
