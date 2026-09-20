import KiwiDeskCore
import SwiftUI

/// The update channel's state as one sentence and one control —
/// drawn by the Home footer and the About sheet alike, so the two
/// cannot say different things (#1536). Grey, don't hide: the
/// checking state dims the arrow in place; a failed check keeps
/// its control enabled, since that failure is retryable.
struct UpdateStateRow: View {
    @ObservedObject var store: UpdateStateStore
    let check: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            switch store.state {
            case .unavailable:
                sentence(
                    L(
                        "updates.state.unavailable",
                        "Update checks are off in this build."
                    ),
                    ink: SettingsTheme.ink3
                )
            case .upToDate(let lastChecked):
                sentence(upToDateSentence(lastChecked))
                checkAgain(enabled: true)
            case .checking:
                sentence(
                    L("updates.state.checking", "Checking for updates…")
                )
                checkAgain(enabled: false)
            case .available(let version):
                Circle()
                    .fill(SettingsTheme.accent)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                sentence(
                    L(
                        "updates.state.available",
                        "Version %1$@ is available.",
                        version
                    ),
                    ink: SettingsTheme.ink
                )
                Button(
                    // The menu-bar row's own string (#1013).
                    L("menu.update_available", "Update Available…"),
                    action: check
                )
                .controlSize(.small)
                .kiwiProminentButton()
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsTheme.warningInk)
                    .accessibilityHidden(true)
                sentence(
                    L(
                        "updates.state.failed",
                        "Couldn't check for updates — you may be offline."
                    ),
                    ink: SettingsTheme.warningInk
                )
                Button(L("updates.try_again", "Try again"), action: check)
                    .controlSize(.small)
                    .settingsActionButton()
            }
        }
        .font(.system(size: 12))
    }

    private func sentence(
        _ text: String,
        ink: Color = SettingsTheme.ink2
    ) -> some View {
        Text(text).foregroundStyle(ink).fixedSize(
            horizontal: false,
            vertical: true
        )
    }

    private func checkAgain(enabled: Bool) -> some View {
        Button(action: check) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(enabled ? SettingsTheme.ink2 : SettingsTheme.ink3)
        .disabled(!enabled)
        .help(
            enabled
                ? L("updates.check_again", "Check for updates again")
                : L("updates.state.checking", "Checking for updates…")
        )
        .accessibilityLabel(
            L("updates.check_again", "Check for updates again")
        )
    }

    private func upToDateSentence(_ lastChecked: Date?) -> String {
        Self.upToDateSentence(lastChecked, now: Date())
    }

    /// "Up to date", dated by the last check where one is known —
    /// relative, in the GUI's own locale rather than the system's.
    static func upToDateSentence(
        _ lastChecked: Date?,
        now: Date
    ) -> String {
        guard let lastChecked else {
            return L("updates.state.up_to_date", "Up to date")
        }
        // Sparkle stamps the check a beat after the footer's "now",
        // and a formatter reads that as "in 0 seconds".
        if now.timeIntervalSince(lastChecked) < 60 {
            return L(
                "updates.state.up_to_date_just_now",
                "Up to date · checked just now"
            )
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(
            identifier: LocalizationManager.shared.effectiveLocale ?? "en"
        )
        formatter.unitsStyle = .full
        return L(
            "updates.state.up_to_date_checked",
            "Up to date · last checked %1$@",
            formatter.localizedString(for: lastChecked, relativeTo: now)
        )
    }
}
