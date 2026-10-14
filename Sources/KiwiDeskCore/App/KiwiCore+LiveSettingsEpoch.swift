import Foundation

/// The live settings' epoch (#1685): it moves wherever they are
/// replaced wholesale, so a caller holding unkept changes learns
/// they are gone, and it names this process, so a relaunch is
/// never read as the same settings.
extension KiwiCore {
    /// This process's epoch: opaque, compared only for equality.
    public var settingsEpoch: String {
        "\(settingsEpochOwner):\(settingsReplacements)"
    }

    /// The one wholesale write of the live settings. A new one
    /// takes this door, or `LiveSettingsReplaceCensusTests` reds.
    func replaceLiveSettings(_ settings: TilingSettings) {
        settingsReplacements += 1
        tiler.settings = settings
    }

    /// A replacement that writes the settings piecewise — a config
    /// load runs `init.lua`'s setters over a reset.
    func noteLiveSettingsReplaced() {
        settingsReplacements += 1
    }
}

extension KiwiCore {
    /// Runs `write`, a write of files alone, and puts back any
    /// live value it moved: the shared look's landing repaints the
    /// live look from the files, which still hold the stored value
    /// of every look leaf a keep did not name (#1685). The epoch is
    /// put back with it, since nothing live was replaced.
    func preservingLiveSettings(_ write: () -> Void) {
        let live = tiler.settings
        let replacements = settingsReplacements
        write()
        settingsReplacements = replacements
        guard tiler.settings != live else { return }
        tiler.settings = live
        retile(pass: .apply)
    }
}
