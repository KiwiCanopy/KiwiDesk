import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The switch cues (#2142, #2144, #2143): fed by Core's payers,
    /// which have already decided they show; the GUI draws each
    /// on the screen Core names, in one plate.
    func wireCuePlate() {
        core.onDesktopCue = { [weak self] cue in
            guard let self,
                let screen = self.core.screen(for: cue.display)
            else { return }
            self.cuePlate.show(.desktop(cue), on: screen)
        }
        core.onModeCue = { [weak self] cue in
            guard let self,
                let screen = self.core.screen(for: cue.display)
            else { return }
            self.cuePlate.show(.mode(cue), on: screen)
        }
        core.onSpaceCue = { [weak self] cue in
            guard let self,
                let screen = self.core.screen(for: cue.display)
            else { return }
            self.cuePlate.show(.space(cue), on: screen)
        }
    }
}
