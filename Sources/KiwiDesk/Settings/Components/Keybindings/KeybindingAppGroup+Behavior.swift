import KiwiDeskCore
import SwiftUI

/// Launch behavior picker menu for application shortcuts
/// (`AppShortcutAction`, #334).
extension ApplicationsGroup {
    @ViewBuilder
    func behaviorMenu(
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
                ) { behavior in
                    Button(behaviorLabel(behavior)) {
                        setBehavior(binding, behavior)
                    }
                    .disabled(
                        behavior != current
                            && behaviorTaken(
                                behavior,
                                bundleID: bundleID,
                                excluding: binding.wrappedValue.id
                            )
                    )
                }
            } label: {
                behaviorLabelView(behaviorLabel(current))
            }
            .menuStyle(.borderlessButton)
            .neutralMenuLabel()
            .fixedSize()
            .accessibilityLabel(
                L("shortcuts.app_behavior", "Action")
            )
            .accessibilityValue(behaviorLabel(current))
            HelpButton(
                explanation: behaviorHelp,
                subject: L("shortcuts.app_behavior", "Action")
            )
        }
    }

    func behaviorLabel(_ behavior: AppShortcutAction) -> String {
        switch behavior {
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

    /// Help explanation text for launch behavior options (#673).
    private var behaviorHelp: String {
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

    /// Rewrites Lua binding command to selected launch behavior.
    private func setBehavior(
        _ binding: Binding<KeyBinding>,
        _ behavior: AppShortcutAction
    ) {
        guard
            let bundleID = KeybindingCatalog.appBundleID(
                from: binding.wrappedValue.lua
            )
        else { return }
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            bundleID,
            behavior: behavior
        )
    }

    /// Checks if target bundle ID already binds the specified behavior.
    private func behaviorTaken(
        _ behavior: AppShortcutAction,
        bundleID: String?,
        excluding id: UUID?
    ) -> Bool {
        guard let bundleID else { return false }
        return KeybindingCatalog.takenBehaviors(
            for: bundleID,
            in: bindings,
            excluding: id
        ).contains(behavior)
    }

    /// Finds first unbound launch behavior for the application (#334).
    func firstAvailableBehavior(
        for bundleID: String
    ) -> AppShortcutAction? {
        KeybindingCatalog.firstAvailableBehavior(
            for: bundleID,
            in: bindings
        )
    }

    /// Label view with dropdown chevron (`AppRuleMenuLabel`).
    private func behaviorLabelView(
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
