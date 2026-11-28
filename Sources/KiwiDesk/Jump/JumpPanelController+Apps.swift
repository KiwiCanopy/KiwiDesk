import AppKit
import KiwiDeskCore
import os

/// The Windows side's Applications section (#3704): the candidates an
/// opening ranks, Core's answer at the press, and the open itself.
extension JumpPanelController {
    /// The installed apps of a finished scan — never starting one on
    /// the hotkey path (#3276) — and Core's running apps.
    static func appCandidates(_ snapshot: JumpSnapshot) -> [JumpAppCandidate] {
        JumpAppCandidate.build(
            installed: InstalledApps.scanned ?? [],
            running: snapshot.running,
            own: Bundle.main.bundleIdentifier
        )
    }

    func wireApps(_ model: JumpModel) {
        model.openRefusal = { [weak self] in self?.core.openAppRefusal($0) }
        model.onOpenApp = { [weak self] in self?.openApp($0) }
    }

    /// Closes on an Applications row's ↩, then opens the app; no
    /// window of ours is handed back to.
    func openApp(_ bundleID: String) {
        guard dismiss(distrusting: true) else { return }
        jumpLog.log("KiwiDesk: jump open app")
        core.openApp(bundleID)
    }
}
