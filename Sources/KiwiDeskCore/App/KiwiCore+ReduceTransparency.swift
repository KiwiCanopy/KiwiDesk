import AppKit

/// Reduce transparency re-draws both bars (#1374). The token lives
/// on `AppBarManager` (`transparencyObserver`) and the handler
/// body is named so a test can drive it without the notification;
/// the ⌃⌥K panel re-reads its SwiftUI environment on its own.
extension KiwiCore {
    func wireReduceTransparency() {
        appBars.transparencyObserver = LiquidGlassGate.observe {
            [weak self] in
            self?.reduceTransparencyDidChange()
        }
    }

    /// The observer body: both bars, from their drivers.
    func reduceTransparencyDidChange() {
        updateAppBar()
        updateSpaceBar()
    }
}
