import AppKit

/// Reduce transparency re-draws both bars (#1374). Wired in
/// `start()` and retired in `stop()`, symmetric like `sleepWake`,
/// since a permission revoke stops and re-starts one core; the
/// token lives on `AppBarManager` (`transparencyObserver`) and the
/// handler body is named so a test can drive it without the
/// notification. The ⌃⌥K panel re-reads its SwiftUI environment
/// on its own.
extension KiwiCore {
    func wireReduceTransparency() {
        retireReduceTransparency()
        appBars.transparencyObserver = LiquidGlassGate.observe {
            [weak self] in
            self?.reduceTransparencyDidChange()
        }
    }

    func retireReduceTransparency() {
        guard let token = appBars.transparencyObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(token)
        appBars.transparencyObserver = nil
    }

    /// The observer body: both bars, from their drivers.
    func reduceTransparencyDidChange() {
        updateBars()
    }
}
