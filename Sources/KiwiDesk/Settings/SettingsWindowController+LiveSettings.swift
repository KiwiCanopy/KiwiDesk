import KiwiDeskCore

/// Windows with a live-rows ask already queued this main turn.
@MainActor private var liveAskQueued: Set<ObjectIdentifier> = []

extension SettingsWindowController {
    /// The live settings moved — a verb, the CLI, Lua — while
    /// Settings is open: the draft's unedited leaves follow live
    /// (#3098) and its "Live, not saved" rows ask Core again
    /// (#2262), since a window the user only looks at is never
    /// keyed again. Once per main turn, after the settings write
    /// that called it, so a burst of writes reads the profile once.
    func liveSettingsChanged() {
        let id = ObjectIdentifier(self)
        guard isShown, liveAskQueued.insert(id).inserted else { return }
        Task { @MainActor [weak self] in
            liveAskQueued.remove(id)
            self?.model.liveSettingsMoved()
        }
    }
}
