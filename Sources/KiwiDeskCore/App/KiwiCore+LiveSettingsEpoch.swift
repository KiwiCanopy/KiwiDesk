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
