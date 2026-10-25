import KiwiDeskCore

extension AppDelegate {
    /// Core's one settings hook, which reaches every reader through
    /// `settingsReadersChanged` (#2604).
    func wireSettingsReaders() {
        core.onSettingsChange = { [weak self] in
            self?.settingsReadersChanged($0)
        }
    }

    /// Every GUI surface that stays up over the live settings and
    /// draws them. A new reader joins here, never a second
    /// assignment of the hook.
    func settingsReadersChanged(_ settings: TilingSettings) {
        jumpPanel?.settingsChanged(settings)
    }
}
