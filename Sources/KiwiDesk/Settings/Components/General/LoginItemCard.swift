import AppKit
import KiwiDeskCore
import SwiftUI

/// Login item row (`general.login_item.start`, #576, #678, #864, #1071).
///
/// Controls `SMAppService` login item; crash restart is handled by CLI
/// `kiwidesk service` (#1068). Reads and writes async via `AutoStartManager`.
/// Core returns `AutoStartStatus`, GUI renders copy (#96); greys when
/// unregisterable (#171, #342).
struct LoginItemCard: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DropdownRow(
                label: startLabel,
                spokenValue: nil,
                help: startHelp
            ) {
                Toggle("", isOn: loginBinding)
                    .labelsHidden()
                    .disabled(loginInert)
            }
            confirmation
            caption
        }
        .onAppear { model.refreshAutoStart() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in model.refreshAutoStart() }
    }

    /// Row label key (`SettingsMetrics.labelColumn`, #818, #864).
    private var startLabel: String {
        L("general.login_item.start", "Start at login")
    }

    /// Field-level help (#94, #1071).
    private var startHelp: String {
        L(
            "general.login_item.start_help_login_only",
            "KiwiDesk opens when you sign in, so your windows "
                + "are arranged from the start."
        )
    }

    /// Toggle greyed state (#171, #342): the durable reason (an
    /// unregisterable copy) comes from the gate resolver, never a
    /// predicate re-derived here — so the grey and the
    /// census-declared gate cannot drift; the transient
    /// load/write block is added on top.
    private var loginInert: Bool {
        model.autoStartLoading
            || model.generalGates
                .inertReason(for: .general(.startAtLogin)) != nil
    }

    /// Drives `.off` ↔ `.atLogin` without modifying service agent (#1071).
    private var loginBinding: Binding<Bool> {
        Binding(
            get: { model.autoStart.level.opensAtLogin },
            set: { on in
                guard
                    model.autoStart.level != .atLoginWithAutoRestart
                else { return }
                model.setLoginItem(on, reduceMotion: reduceMotion)
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
        if model.autoStartBusy {
            Text(L("general.login_item.updating", "Updating…"))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
        } else if let applied = model.autoStartApplied {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(confirmationText(applied))
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.groupHeading)
            .transition(.opacity)
        }
    }

    /// Confirmation text for applied auto-start level.
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

    /// Read-through caption and state notices.
    @ViewBuilder private var caption: some View {
        Text(
            L(
                "general.login_item.stored_by_macos",
                "Read live from macOS, stored there too — may "
                    + "need approval in System Settings."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        if model.autoStart.requiresApproval {
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
                .settingsActionButton()
            }
        }
        // Checked independently from requiresApproval branch (#1071).
        if let reason = model.generalGates.inertReason(
            for: .general(.startAtLogin)
        ) {
            unavailableCaption(GeneralGateHelp.sentence(for: reason))
        }
    }

    /// Shared styling for the two greyed-state captions.
    private func unavailableCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
