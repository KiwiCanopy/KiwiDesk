import Foundation

extension SettingsModel {
    /// What opening Settings does to the model before the window
    /// comes forward (#1970): a fresh open reloads and starts on
    /// Home — no draft outlives the window (#2049, amending #455) —
    /// while a window already shown keeps its draft and the page
    /// the user is on. A navigating open sets its reveal first,
    /// which still lands either way.
    func prepareToShow(windowShown: Bool) {
        if !windowShown || !isDirty {
            reload()
        }
        guard !windowShown else { return }
        destination = nil
        nav.resetSurfaces()
    }
}
