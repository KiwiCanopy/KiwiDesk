import KiwiDeskCore

/// The model half of the search rework (#678 turn 11): the value
/// enrichment read and the one-line mode-switch confirmation.
extension SettingsModel {
    /// Enrichment: the current value of a census key as the diff
    /// rows would narrate it — `SettingsValueReadout` with the
    /// draft on both sides, so the "new" column IS the current
    /// value and search cannot name a value two ways. Reads the
    /// staged config in memory, nothing else. Nil where the key
    /// has no scalar to state (families, actions, added/removed
    /// rows).
    func searchValue(for key: SettingKey) -> String? {
        SettingsValueReadout.rows(
            for: key,
            old: config,
            new: config
        )
        .first?
        .newValue
    }

    /// Shows the one-line confirmation after a search pick
    /// flipped the window into Power User mode (4c): the flip
    /// itself is `ensureModeAdmits`' and stays silent; this line
    /// is the only mention. Self-clears; a second flip
    /// supersedes the first.
    func noteSearchModeSwitch(
        _ destination: SettingsDestination
    ) {
        searchModeNotice = L(
            "search.mode_switched",
            "Power User mode on — %1$@ is now on Home.",
            destination.title
        )
        searchNoticeTask?.cancel()
        searchNoticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.searchModeNotice = nil
        }
    }
}
