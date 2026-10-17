import KiwiDeskCore
import SwiftUI

/// action picker menu for application shortcuts
/// (`AppShortcutAction`, #334).
extension ApplicationsGroup {
    @ViewBuilder
    func actionMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        let lua = binding.wrappedValue.lua
        let bundleID = KeybindingCatalog.appBundleID(from: lua)
        let current =
            KeybindingCatalog.appShortcutAction(from: lua)
            ?? .openOrFocus
        HStack(spacing: 4) {
            Menu {
                ForEach(
                    AppShortcutAction.allCases,
                    id: \.self
                ) { action in
                    Button(actionLabel(action)) {
                        setAction(binding, action)
                    }
                    .disabled(
                        action != current
                            && actionTaken(
                                action,
                                bundleID: bundleID,
                                excluding: binding.wrappedValue.id
                            )
                    )
                }
            } label: {
                actionLabelView(actionLabel(current))
            }
            .menuStyle(.borderlessButton)
            .neutralMenuLabel()
            .fixedSize()
            .menuTriggerHover()
            .accessibilityLabel(
                L("shortcuts.app_behavior", "Action")
            )
            .accessibilityValue(actionLabel(current))
            HelpButton(
                explanation: actionHelp,
                subject: L("shortcuts.app_behavior", "Action")
            )
        }
    }

    func actionLabel(_ action: AppShortcutAction) -> String {
        switch action {
        case .openOrFocus:
            return L(
                "shortcuts.app_behavior.open_or_focus",
                "Open or Focus"
            )
        case .openNew:
            return L("shortcuts.app_behavior.open_new", "Open New")
        case .gather:
            return L("shortcuts.app_behavior.gather", "Gather Windows")
        }
    }

    /// Help explanation text for action options (#673).
    private var actionHelp: String {
        L(
            "shortcuts.app_behavior.help",
            "**%1$@** takes you to the app's existing window, "
                + "wherever it is, or launches the app if it "
                + "isn't running. Pressing again while that window "
                + "is focused cycles through the app's other "
                + "windows. If the app has nothing on screen, "
                + "pressing the shortcut restores its most "
                + "recently minimized window; otherwise "
                + "minimized windows stay in the Dock."
                + "\n\n**%2$@** always launches a "
                + "fresh instance, even when the app is already "
                + "open."
                + "\n\n**%3$@** brings every window of the app "
                + "into the Space you are on, from other Desktops "
                + "too. It never launches the app.",
            L(
                "shortcuts.app_behavior.open_or_focus",
                "Open or Focus"
            ),
            L("shortcuts.app_behavior.open_new", "Open New"),
            L("shortcuts.app_behavior.gather", "Gather Windows")
        )
    }

    /// Rewrites Lua binding command to selected action.
    private func setAction(
        _ binding: Binding<KeyBinding>,
        _ action: AppShortcutAction
    ) {
        guard
            let bundleID = KeybindingCatalog.appBundleID(
                from: binding.wrappedValue.lua
            )
        else { return }
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            bundleID,
            action: action
        )
    }

    /// Checks if target bundle ID already binds the specified action.
    private func actionTaken(
        _ action: AppShortcutAction,
        bundleID: String?,
        excluding id: UUID?
    ) -> Bool {
        guard let bundleID else { return false }
        return KeybindingCatalog.takenActions(
            for: bundleID,
            in: bindings,
            excluding: id
        ).contains(action)
    }

    /// Finds first unbound action for the application (#334).
    func firstAvailableAction(
        for bundleID: String
    ) -> AppShortcutAction? {
        KeybindingCatalog.firstAvailableAction(
            for: bundleID,
            in: bindings
        )
    }

    /// Label view with dropdown chevron (`AppRuleMenuLabel`).
    private func actionLabelView(
        _ text: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
