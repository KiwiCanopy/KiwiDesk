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
            case .notChecked(let lastChecked):
                sentence(Self.notCheckedSentence(lastChecked, now: Date()))
                // Nothing ran yet, so not "again".
                checkAgain(enabled: true, label: checkLabel)
            case .upToDate(let lastChecked):
                sentence(Self.upToDateSentence(lastChecked, now: Date()))
                checkAgain(enabled: true, label: checkAgainLabel)
            case .checking:
                sentence(
                    L("updates.state.checking", "Checking for updates…")
                )
                checkAgain(enabled: false, label: checkAgainLabel)
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
                // The seal ignores `.controlSize`, so it drew at full
                // size in a 12 pt line; the dot carries the accent.
                .controlSize(.small)
                .settingsActionButton()
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

    private var checkLabel: String {
        L("updates.check", "Check for updates")
    }

    private var checkAgainLabel: String {
        L("updates.check_again", "Check for updates again")
    }

    private func checkAgain(enabled: Bool, label: String) -> some View {
        Button(action: check) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(enabled ? SettingsTheme.ink2 : SettingsTheme.ink3)
        .disabled(!enabled)
        .help(
            enabled
                ? label
                : L("updates.state.checking", "Checking for updates…")
        )
        .accessibilityLabel(label)
    }

    /// "Up to date", dated by the last check where one is known.
    static func upToDateSentence(
        _ lastChecked: Date?,
        now: Date
    ) -> String {
        guard let lastChecked else {
            return L("updates.state.up_to_date", "Up to date")
        }
        return L(
            "updates.state.up_to_date_checked",
            "Up to date · last checked %1$@",
            lastCheckedPhrase(lastChecked, now: now)
        )
    }

    /// Before this session's first answer: only WHEN the channel
    /// last checked is known, so no verdict is claimed.
    static func notCheckedSentence(
        _ lastChecked: Date?,
        now: Date
    ) -> String {
        guard let lastChecked else {
            return L("updates.state.not_checked", "Not checked yet")
        }
        return L(
            "updates.state.last_checked",
            "Last checked %1$@",
            lastCheckedPhrase(lastChecked, now: now)
        )
    }

    /// Relative, in the GUI's own locale rather than the system's.
    /// Sparkle stamps a check a beat after the footer's "now", and
    /// a formatter reads that as "in 0 seconds" — so anything
    /// under a minute is "just now".
    static func lastCheckedPhrase(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 {
            return L("updates.relative.just_now", "just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(
            identifier: LocalizationManager.shared.effectiveLocale ?? "en"
        )
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
