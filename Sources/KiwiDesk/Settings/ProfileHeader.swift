import KiwiDeskCore
import SwiftUI

/// Profile edit-target dropdown menu (#18, #94, #251, #259,
/// #1393). Each profile is listed once: what is running on top —
/// the loaded profile, or the built-in or transient layout — then
/// the others, grouped by the screen count they are saved for,
/// the connected count first.
struct ProfileEditTargetMenu: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        // The menu's own trailing inset is the gap before the `?`.
        HStack(spacing: 0) {
            menu
            HelpButton(
                explanation: L(
                    "profile_header.menu.help",
                    "Pick a saved profile to edit — editing it "
                        + "won't switch your layout."
                )
            )
        }
    }

    private var menu: some View {
        Menu {
            Button(checked(liveTitle, nil)) { requestSelect(nil) }
            if !others.isEmpty { Divider() }
            if groups.count > 1 {
                ForEach(groups, id: \.count) { group in
                    Section(Self.countHeader(group.count)) {
                        ForEach(group.names, id: \.self) { name in
                            Button(checked(name, name)) {
                                requestSelect(name)
                            }
                        }
                    }
                }
            } else {
                ForEach(others, id: \.self) { name in
                    Button(checked(name, name)) { requestSelect(name) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up")
                Text(title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        // Closed, the menu shows only its VALUE, so VoiceOver
        // heard a name with no noun — name the control, keep the
        // value (#812, the App Rules facet shape).
        .accessibilityLabel(
            L("profile_header.menu.ax", "Profile to edit")
        )
        .accessibilityValue(spokenValue)
    }

    /// A row's title, marked where it is the open target.
    private func checked(_ label: String, _ name: String?) -> String {
        (model.editingProfile == name ? "✓ " : "") + label
    }

    /// Every profile but the loaded one, in the menu's order.
    private var others: [String] {
        model.profileMenuOrder.filter { $0 != model.activeProfile }
    }

    /// `others` split by the screen count each is saved for.
    private var groups: [(count: Int, names: [String])] {
        let counts = Dictionary(
            model.profileSummaries.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
        var result: [(count: Int, names: [String])] = []
        for name in others {
            let count = counts[name] ?? 0
            if let at = result.firstIndex(where: { $0.count == count }) {
                result[at].names.append(name)
            } else {
                result.append((count, [name]))
            }
        }
        return result
    }

    static func countHeader(_ count: Int) -> String {
        count == 1
            ? L("desktops.for_count.one", "For 1 screen")
            : L("desktops.for_count.many", "For %1$d screens", count)
    }

    private func requestSelect(_ name: String?) {
        // Re-picking the open target is a no-op, so it never pops
        // a pointless discard dialog.
        guard name != model.editingProfile else { return }
        // Confirms discarding pending edits before switching profile
        // (#209, #515).
        model.discardingEdits(
            message: L(
                "discard.switch_profile.message",
                "Switching profiles drops the edits you "
                    + "haven't saved."
            ),
            confirmLabel: L(
                "discard.switch_profile.confirm",
                "Discard & switch"
            )
        ) { model.selectEditTarget(name) }
    }

    /// What is running: the loaded profile, else the layout that
    /// stands in for one.
    private var liveTitle: String {
        if let profile = model.activeProfile { return profile }
        if let standard = model.activeStandard {
            return L(
                "profile_header.title.standard",
                "Standard: %1$@",
                standardDisplayName(standard)
            )
        }
        return L(
            "profile_header.title.transient",
            "Transient layout"
        )
    }

    private var title: String { model.editingProfile ?? liveTitle }

    /// The closed menu's value; the dot beside it is hidden, so the
    /// loaded state is spoken here.
    private var spokenValue: String {
        if let editing = model.editingProfile {
            return L(
                "profile_header.menu.value.not_loaded",
                "%1$@, not loaded",
                editing
            )
        }
        guard let profile = model.activeProfile else { return liveTitle }
        return L("profile_header.menu.value.loaded", "%1$@, loaded", profile)
    }
}
