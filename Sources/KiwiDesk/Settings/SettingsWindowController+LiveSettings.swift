import KiwiDeskCore

extension SettingsWindowController {
    /// The live settings moved — a verb, the CLI, Lua — while
    /// Settings is open: its "Live, not saved" rows ask Core again
    /// (#2262), since a window the user only looks at is never
    /// keyed again. On the next main turn, so the ask never runs
    /// inside the settings write that called it.
    func liveSettingsChanged() {
        guard isShown else { return }
        Task { @MainActor [weak self] in
            self?.model.refreshUnsavedLive()
        }
    }
}
