import Combine
import KiwiDeskCore

/// General's app-wide rows (#1741): read live from the core and
/// written at once, never through the draft — the card they sit
/// on promises "applies immediately".
extension SettingsModel {
    var appWide: AppWideSettings { core.appWide }

    /// What the Hyper key's remap last did (#1870), read live.
    var hyperStatus: HyperKeyStatus { core.keys.hyperStatus }

    func setAppWide(_ change: (inout AppWideSettings) -> Void) {
        objectWillChange.send()
        core.withUserMotion { core.setAppWide(persisting: true, change) }
    }
}
