import Combine
import KiwiDeskCore

/// General's app-wide rows (#1741): read live from the core and
/// written at once, never through the draft — the card they sit
/// on promises "applies immediately".
extension SettingsModel {
    var appWide: AppWideSettings { core.appWide }

    func setAppWide(_ change: (inout AppWideSettings) -> Void) {
        objectWillChange.send()
        core.setAppWide(persisting: true, change)
    }
}
