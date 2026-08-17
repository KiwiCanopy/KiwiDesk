import KiwiDeskCore
import SwiftUI

/// The per-row launch-behavior menu for Open applications (#334):
/// a compact borderless menu (mirroring `AppRuleRow`'s Float facet)
/// choosing between Open or Focus (`pull_or_spawn`, the default) and
/// Open New (`spawn_new`). The behavior is derived from and written
/// back into the binding's `lua` — no persisted field — so the same
/// app can hold one shortcut per behavior without a new row
/// primitive: the dropdown greys a behavior already bound for that
/// app so the pair can't collide, while the other stays reachable.
extension ApplicationsGroup {
    @ViewBuilder
    func behaviorMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        let lua = binding.wrappedValue.lua
        let bundleID = KeybindingCatalog.appBundleID(from: lua)
        let current =
            KeybindingCatalog.appLaunchBehavior(from: lua)
            ?? .openOrFocus
        HStack(spacing: 4) {
            Menu {
                ForEach(
                    AppLaunchBehavior.allCases,
                    id: \.self
                ) { behavior in
                    Button(behaviorLabel(behavior)) {
                        setBehavior(binding, behavior)
                    }
                    // Can't bind the same app+behavior twice; a
                    // different behavior for the app stays open.
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
            HelpButton(
                explanation: behaviorHelp,
                subject: L(
                    "shortcuts.app_behavior",
                    "Launch behavior"
                )
            )
        }
    }

    func behaviorLabel(_ behavior: AppLaunchBehavior) -> String {
        switch behavior {
        case .openOrFocus:
            return L(
                "shortcuts.app_behavior.open_or_focus",
                "Open or Focus"
            )
        case .openNew:
            // Not bare "Open" — ambiguous under a section already
            // titled "Open applications".
            return L("shortcuts.app_behavior.open_new", "Open New")
        }
    }

    /// The minimized sentence (#673) is here rather than on its
    /// own row because it answers a question about *this
    /// control's* two choices — what Open or Focus does when
    /// there is nothing on screen to focus. A separate hint would
    /// be a second explanation of one decision, and the `?`
    /// popover is where a concept belongs.
    private var behaviorHelp: String {
        L(
            "shortcuts.app_behavior.help",
            "**%1$@** brings the app's existing window to "
                + "the current Space, or launches it if the app "
                + "isn't running. Pressing again while that window "
                + "is focused cycles through the app's other "
                + "windows. If the app has nothing on screen, "
                + "pressing the shortcut restores its most "
                + "recently minimized window; otherwise "
                + "minimized windows stay in the Dock."
                + "\n\n**%2$@** always launches a "
                + "fresh instance, even when the app is already "
                + "open.",
            L(
                "shortcuts.app_behavior.open_or_focus",
                "Open or Focus"
            ),
            L("shortcuts.app_behavior.open_new", "Open New")
        )
    }

    /// Rewrites the binding's `lua` to the chosen behavior, keeping
    /// its bundle id. A no-op when the row carries no app yet.
    private func setBehavior(
        _ binding: Binding<KeyBinding>,
        _ behavior: AppLaunchBehavior
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

    /// Whether an application row already binds this exact
    /// app+behavior. `excluding` drops the row being edited.
    private func behaviorTaken(
        _ behavior: AppLaunchBehavior,
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

    /// The first launch behavior not yet bound for this app, or nil
    /// when every behavior is already taken. Seeds a newly added row
    /// so a second binding for the same app lands on a *distinct*
    /// behavior instead of duplicating the default (#334).
    func firstAvailableBehavior(
        for bundleID: String
    ) -> AppLaunchBehavior? {
        KeybindingCatalog.firstAvailableBehavior(
            for: bundleID,
            in: bindings
        )
    }

    /// The borderless-menu signature: primary-ink label + a
    /// trailing secondary chevron so a bare-text menu still reads
    /// as "this opens a menu" — byte-for-byte the same treatment as
    /// `AppRuleRow`'s Float/Space facet menus, so the two sibling
    /// surfaces stay visually consistent.
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
