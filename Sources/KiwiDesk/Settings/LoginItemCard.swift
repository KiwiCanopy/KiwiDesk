import AppKit
import KiwiDeskCore
import SwiftUI

/// The "Start KiwiDesk" card in App ▸ General (#576).
///
/// A single 3-level control replacing #342's plain login toggle:
/// *Never / At Login / At Login, With Auto-Restart*. The upper
/// level is the `kiwidesk service` LaunchAgent (crash-restart) that
/// used to be CLI-only; folding it in over one merged status avoids
/// the two-toggle dishonesty (see `AutoStartManager`).
///
/// A **read-through**, **async** control: it stores no preference,
/// it reads `AutoStartManager.current()` off the main actor on
/// appear and on every `didBecomeActive`, and a level change writes
/// through `AutoStartManager.set(_:)` and adopts the state it reads
/// back. launchctl is a blocking spawn, so the read/write happen on
/// a detached task and publish to `@State` on main; `loaded` gates
/// the pending window before the first read lands.
///
/// Core hands us structure (`AutoStartStatus`); the level labels and
/// captions are rendered here (#96). Levels 2 and 3 grey out (grey,
/// don't hide, #171) when the running copy can't register — a bare
/// binary or a translocated download — leaving only "Never", the
/// exact shape #342's whole-toggle grey took.
struct LoginItemCard: View {
    // Seeded at the opt-in default (At Login); `refresh()` replaces
    // it with the live read before the first paint the user reads.
    // A `@State` default re-runs on every `GeneralSection.body`
    // recompute, so it must stay a cheap literal, never a probe.
    @State private var status = AutoStartStatus(
        level: .atLogin,
        unavailable: nil,
        requiresApproval: false
    )
    // False until the first async read lands; the control is
    // pending (disabled) until then. `busy` covers a `set(_:)` in
    // flight so the menu can't be driven mid-write.
    @State private var loaded = false
    @State private var busy = false
    // The just-applied level, shown as a transient green-check
    // confirmation that fades on its own (the changes apply live, so
    // there is no Save to press). `flashToken` lets a newer change
    // cancel an older fade so a quick succession doesn't clear the
    // latest confirmation early.
    @State private var applied: AutoStartLevel?
    @State private var flashToken = 0
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        SettingsSection(SettingsCatalog.general.loginItemCard) {
            VStack(alignment: .leading, spacing: 6) {
                DropdownRow(
                    // Card heading is the noun "Login"; the control
                    // carries the verb "Start KiwiDesk".
                    label: startLabel,
                    help: startHelp
                ) {
                    Picker(startLabel, selection: levelBinding) {
                        Text(
                            L("general.login_item.level.never", "Never")
                        )
                        .tag(AutoStartLevel.off)
                        Text(
                            L(
                                "general.login_item.level.at_login",
                                "At Login"
                            )
                        )
                        .tag(AutoStartLevel.atLogin)
                        Text(
                            L(
                                "general.login_item.level"
                                    + ".at_login_restart",
                                "Auto-Restart at Login"
                            )
                        )
                        .tag(AutoStartLevel.atLoginWithAutoRestart)
                    }
                    // Grey the Picker only, not the whole row — the
                    // label's `?` (which explains what the three
                    // levels do) stays live even when the control is
                    // greyed, since that help is useful regardless of
                    // whether the levels can be picked right now.
                    //
                    // Levels 2 and 3 both need a stable `.app` path,
                    // so an unregisterable copy (translocated / bare
                    // binary) greys the control; the caption below
                    // names the fix. A per-item `.disabled()` on a
                    // `.menu` Picker blocks selection but AppKit's
                    // NSPopUpButton won't render the item greyed, so
                    // it wouldn't *read* as "grey, don't hide" (#171)
                    // — greying the whole Picker does, matching #342.
                    .disabled(
                        !loaded || busy || !status.registerable
                    )
                }
                confirmation
                caption
            }
        }
        .onAppear { refresh() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in refresh() }
    }

    private var startLabel: String {
        L("general.login_item.start", "Start KiwiDesk")
    }

    /// The one field-level `?` (#94): explains all three levels and
    /// is the only place the crash-restart mechanism is named — the
    /// row itself stays a plain label.
    private var startHelp: String {
        L(
            "general.login_item.start_help",
            "Choose when KiwiDesk starts on its own. "
                + "\u{201C}At Login\u{201D} launches it when you sign "
                + "in, so your windows are arranged from the start. "
                + "\u{201C}Auto-Restart at Login\u{201D} also "
                + "runs a background helper that relaunches KiwiDesk "
                + "if it ever crashes. \u{201C}Never\u{201D} turns "
                + "both off."
        )
    }

    /// Writing a level routes through the facade and adopts the
    /// state it reports back; a no-op selection (same level) is
    /// dropped so re-rendering the picker can't kick a spurious
    /// write.
    ///
    /// The `registerable` guard is the real gate on the upper
    /// levels, not the per-item `.disabled()` on the menu — that
    /// disable is a visual hint SwiftUI does not reliably honor for
    /// individual `.menu`-Picker rows, and the harm it guards
    /// against is a filesystem/launchd side effect, not a cosmetic
    /// one: `apply(.atLoginWithAutoRestart)` would `writePlist()` a
    /// LaunchAgent pointing at the *ephemeral* translocated /
    /// `.build` path, which read-through can't undo (a bootstrapped
    /// service reads back as level 3, so the broken agent persists).
    /// So the setter refuses any level but "Never" on an
    /// unregisterable copy — defense independent of the view layer.
    private var levelBinding: Binding<AutoStartLevel> {
        Binding(
            get: { status.level },
            set: { newLevel in
                guard newLevel != status.level else { return }
                guard status.registerable || newLevel == .off
                else { return }
                busy = true
                Task {
                    let result = await AutoStartManager.set(newLevel)
                    status = result
                    loaded = true
                    busy = false
                    // Confirm the level the OS actually adopted, not
                    // the requested one — a failed apply re-reads to
                    // a different level and should say so.
                    flash(result.level)
                }
            }
        )
    }

    /// The transient live-apply confirmation: "Updating…" while a
    /// change is in flight, then a green check + a level-specific
    /// line that fades on its own (mirrors the key recorder's
    /// `LiveApplyCaption`). Nothing shows at rest, on the initial
    /// read, or on the greyed unregisterable control — only after a
    /// user-driven change, because the changes apply live and there
    /// is no Save to press.
    @ViewBuilder private var confirmation: some View {
        if busy {
            Text(L("general.login_item.updating", "Updating…"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let applied {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(confirmationText(applied))
            }
            .font(.caption)
            .foregroundStyle(.green)
            .transition(.opacity)
        }
    }

    /// The line each applied level confirms — present tense, naming
    /// what will now happen, never a "saved" past tense (nothing was
    /// staged).
    private func confirmationText(_ level: AutoStartLevel) -> String {
        switch level {
        case .off:
            L(
                "general.login_item.applied_off",
                "KiwiDesk won\u{2019}t start on its own."
            )
        case .atLogin:
            L(
                "general.login_item.applied_at_login",
                "KiwiDesk will open at login."
            )
        case .atLoginWithAutoRestart:
            L(
                "general.login_item.applied_restart",
                "KiwiDesk will open at login and restart if it "
                    + "crashes."
            )
        }
    }

    /// Shows the confirmation for `level` and schedules its fade.
    /// `flashToken` guards the fade so a newer change cancels an
    /// older timer rather than clearing the latest confirmation.
    ///
    /// 2.5 s, longer than the key recorder's 1.5 s
    /// (`KeyRecorderField`) on purpose: that caption is a short
    /// phrase read mid-interaction while the user watches for the
    /// next chord, whereas these are full sentences read once after
    /// a single click, so the reading load is ~double. Don't "align"
    /// it back to 1.5 s.
    private func flash(_ level: AutoStartLevel) {
        flashToken += 1
        let token = flashToken
        withAnimation { applied = level }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard flashToken == token else { return }
            withAnimation { applied = nil }
        }
    }

    @ViewBuilder private var caption: some View {
        if status.requiresApproval {
            HStack(spacing: 8) {
                Text(
                    L(
                        "general.login_item.requires_approval",
                        "Requires approval in System Settings"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Button(
                    L(
                        "general.login_item.open_login_items",
                        "Open Login Items"
                    )
                ) {
                    LoginItemManager.openSystemSettingsLoginItems()
                }
                .controlSize(.small)
            }
        } else if status.unavailable == .translocated {
            unavailableCaption(
                L(
                    "general.login_item.unavailable",
                    "Move KiwiDesk to your Applications folder "
                        + "to turn this on."
                )
            )
        } else if status.unavailable == .notBundled {
            unavailableCaption(
                L(
                    "general.login_item.unavailable_binary",
                    "Available only when running the KiwiDesk app."
                )
            )
        }
    }

    /// Shared styling for the two greyed-state captions.
    private func unavailableCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Kicks a fresh off-main dual read and publishes it on main.
    /// Skipped while a `set(_:)` is in flight: a `didBecomeActive`
    /// landing mid-write could otherwise publish a pre-write read
    /// after the write's own re-read, transiently showing a stale
    /// level. The write's re-read already refreshes from OS truth,
    /// so nothing is lost by deferring to the next event.
    private func refresh() {
        guard !busy else { return }
        Task {
            let result = await AutoStartManager.current()
            status = result
            loaded = true
        }
    }
}
