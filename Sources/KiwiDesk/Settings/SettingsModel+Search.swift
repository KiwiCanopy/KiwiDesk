import KiwiDeskCore

/// Search enrichment and mode-switch confirmation for SettingsModel (#678).
extension SettingsModel {
    /// Returns staged value for census key formatted via SettingsValueReadout.
    func searchValue(for key: SettingKey) -> String? {
        SettingsValueReadout.rows(
            for: key,
            old: config,
            new: config
        )
        .first?
        .newValue
    }

    /// Displays self-clearing confirmation when search flips to
    /// Power User mode.
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
