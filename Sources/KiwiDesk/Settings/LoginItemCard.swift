import AppKit
import KiwiDeskCore
import SwiftUI

/// The "Open KiwiDesk at Login" card in App ▸ General (#342).
///
/// A **read-through** control: it never stores a preference, it
/// reads `LoginItemManager.current` (live `SMAppService` status) on
/// appear and on every `didBecomeActive`, so a change made in
/// System Settings ▸ Login Items directly is reflected here with no
/// second source of truth. The switch writes through `setEnabled`,
/// which returns the resulting state.
///
/// Core hands us structure (`LoginItemState`); the sentence is
/// rendered here (#96). Four states:
/// - `.notRegistered` / `.enabled` → plain switch, no caption.
/// - `.requiresApproval` → switch on (reflects the user's intent)
///   plus a status line and a jump to Login Items — the exact shape
///   the onboarding grant step uses for "asked, not yet confirmed".
/// - `.unavailable` → switch greyed but visible (grey, don't hide,
///   #171), with an error caption.
struct LoginItemCard: View {
    // Sentinel until `.onAppear` reads live status. A `@State`
    // default re-runs on every `GeneralSection.body` recompute
    // (a language change, etc.), so seeding it from the live probe
    // would hit `SMAppService` each rebuild for a value SwiftUI
    // keeps only from first render anyway. `refresh()` sets the
    // real state before the first paint the user reads (#342).
    @State private var state: LoginItemState = .notRegistered
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        SettingsSection(SettingsCatalog.general.loginItemCard) {
            VStack(alignment: .leading, spacing: 6) {
                ToggleRow(
                    // Card heading is the noun "Login"; the switch
                    // carries the full action label on its own key.
                    label: L(
                        "general.login_item.switch",
                        "Open KiwiDesk at Login"
                    ),
                    isOn: enabledBinding,
                    help: L(
                        "general.login_item.help",
                        "Launches KiwiDesk automatically when you "
                            + "log in, so your windows are arranged "
                            + "from the moment you sign in."
                    )
                )
                .disabled(isUnavailable)
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

    /// Any `.unavailable(_)` reason greys the switch out.
    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    /// On = enabled or awaiting approval; writing routes through the
    /// manager and adopts the state it reports back.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { state.isOn },
            set: { state = LoginItemManager.setEnabled($0) }
        )
    }

    @ViewBuilder private var caption: some View {
        switch state {
        case .requiresApproval:
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
        case .unavailable(.translocated):
            unavailableCaption(
                L(
                    "general.login_item.unavailable",
                    "Move KiwiDesk to your Applications folder "
                        + "to turn this on."
                )
            )
        case .unavailable(.notBundled):
            unavailableCaption(
                L(
                    "general.login_item.unavailable_binary",
                    "Available only when running the KiwiDesk app."
                )
            )
        case .enabled, .notRegistered:
            EmptyView()
        }
    }

    /// Shared styling for the two greyed-state captions.
    private func unavailableCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func refresh() {
        state = LoginItemManager.current
    }
}
