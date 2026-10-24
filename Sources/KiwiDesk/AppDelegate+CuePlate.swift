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
            self.cuePlate.show(
                .desktop(cue),
                glass: PanelGlass(settings: self.core.tiler.settings),
                on: screen
            )
        }
        core.onModeCue = { [weak self] cue in
            guard let self,
                let screen = self.core.screen(for: cue.display)
            else { return }
            self.cuePlate.show(
                .mode(cue),
                glass: PanelGlass(settings: self.core.tiler.settings),
                on: screen
            )
        }
        // Paid mid-switch; the plate orders in on a later main turn
        // so the switch's own focus and raise go first (#2143).
        core.onSpaceCue = { [weak self] cue in
            DispatchQueue.main.async {
                guard let self,
                    let screen = self.core.screen(for: cue.display)
                else { return }
                self.cuePlate.show(
                    .space(cue),
                    glass: PanelGlass(settings: self.core.tiler.settings),
                    on: screen
                )
            }
        }
    }
}
