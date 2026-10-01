import KiwiDeskCore
import SwiftUI

/// A live Space the profile does not hold (#1790), drawn view-only
/// after the profile's rows: a temporary Space, with the button that
/// adds it to the profile, or a held one (#1507). Never in the
/// draft, so every control shows the LIVE value and is greyed.
struct LiveOnlySpaceRow: View {
    let space: LiveOnlySpace
    /// Writes the Space into the live profile at once.
    let onAdd: () -> Void

    /// The row's reveal anchor — App Rules lands here.
    static func anchor(_ id: SpaceID) -> String {
        "spaces.live_only.\(id.raw)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 24)
                    IconPicker(
                        icon: .constant(space.icon ?? ""),
                        preview: .chip
                    )
                    Text(space.id.raw)
                        .frame(minWidth: 60, alignment: .leading)
                }
                .modifier(GreyOut(active: true, help: lockedHelp))
                chip
                Spacer()
                HStack {
                    modeReadout
                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal, 2)
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 24)
                }
                .modifier(GreyOut(active: true, help: lockedHelp))
            }
            if case .temporary = space.kind { addButton }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(SettingsTheme.hairline)
        )
        .modifier(RowActionsIfTemporary(row: self))
        .liveSpaceAnchored(Self.anchor(space.id))
    }

    private var lockedHelp: String {
        switch space.kind {
        case .temporary:
            L(
                "spaces.temporary.locked.help",
                "Add this Space to the profile to change it"
            )
        case .held(let screen, let profile):
            Self.heldHelp(screen, profile)
        }
    }

    @ViewBuilder private var chip: some View {
        switch space.kind {
        case .temporary:
            BadgeChip(label: L("spaces.temporary_badge", "Temporary"))
                .help(
                    L(
                        "spaces.temporary_badge.help",
                        "Made on the fly. It goes away once its last "
                            + "window leaves; switching profiles keeps "
                            + "it while it has windows."
                    )
                )
        case .held(let screen, let profile):
            BadgeChip(label: Self.heldLabel(screen, profile), maxWidth: 180)
                .help(Self.heldHelp(screen, profile))
        }
    }

    /// Where it was held from: its profile where one was live, else
    /// its screen (#1507, #1790).
    private static func heldLabel(
        _ screen: String,
        _ profile: String?
    ) -> String {
        guard let profile else {
            return L("spaces.held_badge", "Held from %1$@", screen)
        }
        return L(
            "spaces.held_badge.profile",
            "Held from %1$@ · %2$@",
            profile,
            screen
        )
    }

    private static func heldHelp(
        _ screen: String,
        _ profile: String?
    ) -> String {
        guard let profile else {
            return L(
                "spaces.held_badge.help",
                "Goes back to its own profile when %1$@ is connected "
                    + "again",
                screen
            )
        }
        return L(
            "spaces.held_badge.profile.help",
            "Goes back when %1$@ is live again with %2$@ connected",
            profile,
            screen
        )
    }

    /// The live mode, as the profile row's picker draws it.
    private var modeReadout: some View {
        Picker("", selection: .constant(space.mode)) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.symbol)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        .frame(width: 150)
        .accessibilityLabel(
            L("spaces.mode.help", "Layout mode for this Space")
        )
        .accessibilityValue(space.mode.displayName)
    }

    var addTitle: String {
        L(
            "spaces.add_to_profile",
            "Add Space %1$@ to this profile",
            space.id.raw
        )
    }

    var addButton: some View {
        Button(addTitle, action: onAdd)
            .settingsActionButton()
            .disabled(!space.canAdd)
            .help(
                space.canAdd
                    ? ""
                    : L(
                        "spaces.add_to_profile.no_profile",
                        "Save this setup as a profile first"
                    )
            )
    }
}

/// A temporary row's one action on every channel (#845); a held row
/// has none.
private struct RowActionsIfTemporary: ViewModifier {
    let row: LiveOnlySpaceRow

    @ViewBuilder
    func body(content: Content) -> some View {
        if case .temporary = row.space.kind {
            content.rowActions {
                Button(row.addTitle, action: row.onAdd)
                    .disabled(!row.space.canAdd)
            }
        } else {
            content
        }
    }
}
