import KiwiDeskCore
import SwiftUI

/// A layer's "Applies to" control (#2022): App Rules' closed label
/// and ⚠, opening the layer's checklist, where a tick is
/// membership.
struct LayerReachControl: View {
    @ObservedObject var model: SettingsModel
    let layer: String
    let reading: RuleReachReading
    @State private var request: RuleReachRequest?

    var body: some View {
        Button {
            request = RuleReachRequest(id: layer)
        } label: {
            HStack(spacing: 4) {
                AppRuleMenuLabel(text: RuleReachWords.label(reading))
                if RuleReachWords.differing(reading) != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.warningInk)
                }
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(RuleReachWords.ink(reading))
        .frame(minWidth: SettingsMetrics.ruleReachColumn, alignment: .leading)
        .help(RuleReachWords.spoken(reading))
        .accessibilityLabel(L("app_rules.reach", "Applies to"))
        .accessibilityValue(RuleReachWords.spoken(reading))
        .popover(item: $request, arrowEdge: .bottom) { _ in
            LayerReachChecklist(model: model, layer: layer)
        }
    }
}

/// The words a layer's control, its delete dialog and its rename
/// say (#2022), one home so drawn and spoken forms cannot drift.
/// A count goes last (localization.md).
@MainActor
enum LayerReachWords {
    static func caption(_ layer: String) -> String {
        L(
            "shortcuts.layer_reach.caption",
            "Profiles that have the “%1$@” layer",
            layer
        )
    }

    static var leftOut: String {
        L("shortcuts.layer_reach.left_out", "⚠ Left out of this layer")
    }

    /// A shortcut row's checklist, on a profile without its layer.
    static func lacking(_ layer: String) -> String {
        L(
            "shortcuts.layer_reach.lacking",
            "⚠ No “%1$@” layer here",
            layer
        )
    }

    static var storedPage: String {
        L(
            "shortcuts.layer_reach.stored_page",
            "Shared layers are renamed and deleted on the loaded "
                + "profile's page."
        )
    }

    static func deleteTitle(_ layer: String) -> String {
        L(
            "shortcuts.layer_delete.title",
            "Delete the “%1$@” layer?",
            layer
        )
    }

    static func deleteMessage(_ count: Int, _ reading: RuleReachReading?)
        -> String
    {
        let first = L(
            "shortcuts.layer_delete.message",
            "This removes its shortcuts and every shortcut that "
                + "switches to it, %1$d in all.",
            count
        )
        guard let reading, let second = others(reading) else {
            return first
        }
        return L(
            "shortcuts.layer_delete.message_pair",
            "%1$@ %2$@",
            first,
            second
        )
    }

    /// Whether the dialog offers a scope: another profile has it.
    static func isShared(_ reading: RuleReachReading?) -> Bool {
        (reading?.users.count ?? 0) > 1
    }

    static var delete: String {
        L("shortcuts.layer_delete.delete", "Delete")
    }

    static func deleteHere(_ reading: RuleReachReading) -> String {
        L("shortcuts.layer_delete.here", "Delete from %1$@", reading.editing)
    }

    /// The everywhere button, on `removeEverywhere`'s ladder.
    static func deleteEverywhere(_ reading: RuleReachReading) -> String {
        switch RuleReachWords.ladder(reading) {
        case .every:
            return L(
                "shortcuts.layer_delete.everywhere",
                "Delete from every profile"
            )
        case .pair(let first, let second):
            return L(
                "shortcuts.layer_delete.pair",
                "Delete from %1$@ and %2$@",
                first,
                second
            )
        case .count(let count):
            return L(
                "shortcuts.layer_delete.count",
                "Delete from every profile using it (%1$d)",
                count
            )
        }
    }

    /// Where a rename reaches; nil while it is the page's alone.
    static func renameReach(_ reading: RuleReachReading) -> String? {
        switch RuleReachWords.ladder(reading) {
        case .every:
            return L(
                "shortcuts.layer_rename.everywhere",
                "Renames it in every profile."
            )
        case .pair(let first, let second):
            return L(
                "shortcuts.layer_rename.pair",
                "Renames it in %1$@ and %2$@.",
                first,
                second
            )
        case .count(let count):
            guard count > 1 else { return nil }
            return L(
                "shortcuts.layer_rename.count",
                "Renames it in profiles: %1$d.",
                count
            )
        }
    }

    /// Add refused on a stored page for a shared layer's name.
    static var joinOnLoadedPage: String {
        L(
            "shortcuts.add_layer.stored_page",
            "Shared layers are joined on the loaded profile's page."
        )
    }

    /// Adding the name of a shared layer this profile leaves out.
    static func rejoins(_ name: String) -> String {
        L(
            "shortcuts.add_layer.rejoins",
            "Puts this profile back in the shared “%1$@” layer.",
            name
        )
    }

    static func clash(_ profile: String, _ name: String) -> String {
        L(
            "shortcuts.layer_rename.clash",
            "%1$@ already has a “%2$@” layer.",
            profile,
            name
        )
    }

    private static func others(_ reading: RuleReachReading) -> String? {
        let users = reading.profiles.filter(reading.users.contains)
        let others = users.filter { $0 != reading.editing }
        if others.isEmpty { return nil }
        if users.count >= reading.profiles.count {
            return L(
                "shortcuts.layer_delete.every_profile",
                "Every profile has this layer."
            )
        }
        switch others.count {
        case 1:
            return L(
                "shortcuts.layer_delete.also_one",
                "It's also in %1$@.",
                others[0]
            )
        case 2:
            return L(
                "shortcuts.layer_delete.also_two",
                "It's also in %1$@ and %2$@.",
                others[0],
                others[1]
            )
        default:
            return L(
                "shortcuts.layer_delete.also_count",
                "Other profiles that have it: %1$d.",
                others.count
            )
        }
    }
}
