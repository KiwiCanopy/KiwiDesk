import KiwiDeskCore
import SwiftUI

/// Add-row view and application binding creation for ApplicationsGroup (#334).
extension ApplicationsGroup {
    var addRow: some View {
        HStack {
            AppPickerButton(
                placeholder: L(
                    "shortcuts.choose_app",
                    "Choose app…"
                ),
                selection: newApp?.name,
                onPick: { newApp = $0 },
                escapeLabel: L(
                    "shortcuts.other_ellipsis",
                    "Other…"
                ),
                onEscape: {
                    if let app = pickBundleFromPanel() {
                        newApp = app
                    }
                },
                exclude: fullyBoundBundleIDs()
            )
            // Hug the content, like the per-row picker.
            .fixedSize()
            Button {
                addApplication()
            } label: {
                Label(
                    L(
                        "shortcuts.add_application",
                        "Add application"
                    ),
                    systemImage: "plus"
                )
            }
            .settingsActionButton()
            .disabled(newApp == nil || newAppFullyBound)
        }
    }

    private func addApplication() {
        guard let app = newApp else { return }
        // Seed the first behavior not already bound for this app, so
        // re-adding it lands on a distinct behavior instead of a
        // duplicate default. Both taken ⇒ nothing to add (the Add
        // button is greyed for that case).
        guard
            let behavior = firstAvailableBehavior(for: app.bundleID)
        else {
            newApp = nil
            return
        }
        var binding = KeyBinding(kind: .application)
        binding.label = app.name
        binding.lua = KeybindingCatalog.appCommand(
            app.bundleID,
            behavior: behavior
        )
        bindings.append(binding)
        newApp = nil
    }

    /// True if selected application has all launch behaviors already bound.
    private var newAppFullyBound: Bool {
        guard let app = newApp else { return false }
        return firstAvailableBehavior(for: app.bundleID) == nil
    }

    /// Bundle IDs that already carry every launch behavior (#334).
    func fullyBoundBundleIDs(
        excluding id: UUID? = nil
    ) -> Set<String> {
        var seen: [String: Set<AppLaunchBehavior>] = [:]
        for binding in bindings
        where binding.kind == .application && binding.id != id {
            guard
                let bundleID = KeybindingCatalog.appBundleID(
                    from: binding.lua
                )
            else { continue }
            let behavior =
                KeybindingCatalog.appLaunchBehavior(
                    from: binding.lua
                ) ?? .openOrFocus
            seen[bundleID, default: []].insert(behavior)
        }
        let all = Set(AppLaunchBehavior.allCases)
        return Set(
            seen.filter { $0.value == all }.map(\.key)
        )
    }
}
