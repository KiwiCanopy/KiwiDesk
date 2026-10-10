import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The Desktop switch cue (#2142): fed by Core's one payer,
    /// which has already decided it shows; the GUI draws it on the
    /// screen Core names.
    func wireDesktopCue() {
        core.onDesktopCue = { [weak self] cue in
            guard let self,
                let screen = self.core.screen(for: cue.display)
            else { return }
            self.desktopCuePlate.show(cue, on: screen)
        }
    }
}
