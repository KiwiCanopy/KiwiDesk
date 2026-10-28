import KiwiDeskCore
import SwiftUI

/// Simple's Spaces card (#2737 ruling 4): one row per Space, drawn
/// with the Spaces page's own parts — the grip, the identifier chip
/// (the Space Bar's icon-else-id, opening the icon picker), the
/// name, the Customize badge where it has overrides, "Pin offline",
/// the Screen menu on two or more screens, the Layout menu and the
/// trash — and "+ Add Space" at the end.
struct SimpleSpacesCard: View {
    @ObservedObject var model: SettingsModel
    @State private var notices: [SpaceID: SpaceNameNotice] = [:]
    @StateObject private var reorder = SpaceReorder(
        listSpace: "simpleSpaces"
    )
    /// Set only for a Space that carries overrides; a plain one
    /// deletes in one click (#205).
    @State private var pendingDelete: SpaceID?
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        SimpleCard(title: SettingsDestination.spaces.title) {
            VStack(spacing: 4) {
                ForEach(
                    reorder.displayed(model.config.spaces),
                    id: \.raw
                ) { space in
                    row(space)
                }
            }
            .spaceReorderList(reorder)
            SpaceAddRow(spaces: model.takenSpaceNames) {
                model.config.spaces.append($0)
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.spaces.title,
                destination: .spaces
            )
        }
        .onChange(of: activeState) { _, now in
            if now != .key { reorder.abandon(to: model) }
        }
        .confirmationDialog(
            SpaceDeleteWording.title,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { space in
            Button(SpaceDeleteWording.delete, role: .destructive) {
                model.removeSpace(space)
            }
            Button(SpaceDeleteWording.cancel, role: .cancel) {}
        } message: { _ in
            Text(SpaceDeleteWording.overridesMessage)
        }
    }

    /// The way to the rest of Spaces, its link at the slot.
    @MainActor static var hintProse: String {
        L(
            "simple.spaces.hint",
            "Want more Spaces, %1$@ or per-Space tuning? %2$@ in "
                + "%3$@.",
            SettingsDestination.layoutDefaults.title,
            CrossReferenceRow.linkSlot,
            SettingsRootSwitch.advancedTitle
        )
    }

    private func row(_ space: SpaceID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SpaceDragHandle(model: model, reorder: reorder, space: space)
                IconPicker(
                    icon: model.spaceIconBinding(space),
                    preview: .chip,
                    emptyText: model.spaceIdentifierText(space)
                )
                SpaceNameField(
                    space: space,
                    isAvailable: { !model.takenSpaceNames.contains($0) },
                    onRename: {
                        model.config.renameSpace(from: space, to: $0)
                    },
                    onNotice: { notices[space] = $0 }
                )
                if hasOverrides(space) {
                    SpaceCustomizeButton(model: model, space: space) {
                        model.openAdvanced(
                            SettingsAnchor(landing: .space(space))
                        )
                    }
                }
                SpacePinChip(model: model, space: space, offlineOnly: true)
                Spacer(minLength: 8)
                if model.offersScreenMenu {
                    SpaceScreenMenu(model: model, space: space)
                }
                SpaceModeMenu(model: model, space: space)
                Divider().frame(height: 16)
                SpaceDeleteButton { requestRemove(space) }
            }
            if let notice = notices[space] {
                SpaceNameNoticeCaption(notice: notice)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(SettingsTheme.card)
        .spaceDragLift(space, in: reorder)
    }

    private func requestRemove(_ space: SpaceID) {
        if model.config.carriesOverrides(space) {
            pendingDelete = space
        } else {
            model.removeSpace(space)
        }
    }

    private func hasOverrides(_ space: SpaceID) -> Bool {
        model.config.settings.spaceOverrideCount(for: space) > 0
    }
}
