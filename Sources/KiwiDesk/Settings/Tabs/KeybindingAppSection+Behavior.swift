import KiwiDeskCore
import SwiftUI

/// The per-row launch-behavior menu for Open Applications (#334):
/// a compact borderless menu (mirroring `AppRuleRow`'s Float facet)
/// choosing between Open or Focus (`pull_or_spawn`, the default) and
/// Open New (`spawn_new`). The behavior is derived from and written
/// back into the binding's `lua` — no persisted field — so the same
/// app can hold one shortcut per behavior without a new row
/// primitive: the dropdown greys a behavior already bound for that
/// app so the pair can't collide, while the other stays reachable.
extension ApplicationsSection {
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
            // titled "Open Applications".
            return L("shortcuts.app_behavior.open_new", "Open New")
        }
    }

    private var behaviorHelp: String {
        L(
            "shortcuts.app_behavior.help",
            "**Open or Focus** brings the app's existing window to "
                + "the current space, or launches it if the app "
                + "isn't running.\n\n**Open New** always launches a "
                + "fresh instance, even when the app is already "
                + "open."
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

    /// Whether another application row already binds this exact
    /// app+behavior — the row being edited excluded.
    private func behaviorTaken(
        _ behavior: AppLaunchBehavior,
        bundleID: String?,
        excluding id: UUID
    ) -> Bool {
        guard let bundleID else { return false }
        return bindings.contains { other in
            other.id != id
                && other.kind == .application
                && KeybindingCatalog.appBundleID(from: other.lua)
                    == bundleID
                && (KeybindingCatalog.appLaunchBehavior(
                    from: other.lua
                ) ?? .openOrFocus) == behavior
        }
    }

    /// The borderless-menu signature: a trailing chevron so a
    /// bare-text menu still reads as "this opens a menu" (matches
    /// `AppRuleRow`'s facet menus).
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
