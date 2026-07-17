import KiwiDeskCore
import SwiftUI

/// The Open Applications add-row: pick an app, then commit it —
/// mirroring App Rules, so a new binding always lands with an app
/// identity (its shortcut is recorded afterward in the row). Apps
/// that already carry every launch behavior are dropped from the
/// picker and the Add button greys, so re-adding can only ever
/// produce a *distinct* behavior, never a duplicate (#334).
extension ApplicationsSection {
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
                // Drop apps that already carry every launch
                // behavior — re-adding could only duplicate (#334).
                exclude: fullyBoundBundleIDs
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
            .buttonStyle(.bordered)
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

    /// The picked add-row app already has every launch behavior
    /// bound — adding it again would only duplicate. Greys the Add
    /// button (grey-don't-hide) instead of silently no-opping. A
    /// backstop for the "Other…" panel, which can still reach a
    /// fully-bound bundle the picker list already omits.
    private var newAppFullyBound: Bool {
        guard let app = newApp else { return false }
        return firstAvailableBehavior(for: app.bundleID) == nil
    }

    /// Bundle ids that already carry every launch behavior, hidden
    /// from the add-row picker (#334).
    private var fullyBoundBundleIDs: Set<String> {
        var seen: [String: Set<AppLaunchBehavior>] = [:]
        for binding in bindings where binding.kind == .application {
            guard
                let id = KeybindingCatalog.appBundleID(
                    from: binding.lua
                )
            else { continue }
            let behavior =
                KeybindingCatalog.appLaunchBehavior(
                    from: binding.lua
                ) ?? .openOrFocus
            seen[id, default: []].insert(behavior)
        }
        let all = Set(AppLaunchBehavior.allCases)
        return Set(
            seen.filter { $0.value == all }.map(\.key)
        )
    }
}
