import Foundation

extension SettingsModel {
    /// What opening Settings does to the model before the window
    /// comes forward (#455, #1970): a clean draft reloads, and a
    /// fresh open starts on Home — while a window already shown
    /// keeps the page the user is on. A navigating open sets its
    /// reveal first, which still lands either way.
    func prepareToShow(windowShown: Bool) {
        if !isDirty {
            reload()
        }
        guard !windowShown else { return }
        destination = nil
        nav.resetSurfaces()
    }
}
