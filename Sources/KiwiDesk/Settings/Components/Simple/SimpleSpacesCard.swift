import KiwiDeskCore
import SwiftUI

/// Simple's Spaces card (#2737 ruling 4): one row per Space — its
/// number, name, Customize badge where it has overrides, the
/// Screen menu on two or more screens, and the Layout menu. No add,
/// delete or reorder.
struct SimpleSpacesCard: View {
    @ObservedObject var model: SettingsModel
    @State private var notices: [SpaceID: SpaceNameNotice] = [:]

    var body: some View {
        SimpleCard(title: SettingsDestination.spaces.title) {
            VStack(spacing: 4) {
                ForEach(
                    Array(model.config.spaces.enumerated()),
                    id: \.element
                ) { index, space in
                    row(space, number: index + 1)
                }
            }
            CrossReferenceRow(
                prose: Self.hintProse,
                linkTitle: SettingsDestination.spaces.title,
                destination: .spaces
            )
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

    private func row(_ space: SpaceID, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(SettingsTheme.sunken)
                    )
                    .accessibilityHidden(true)
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
            }
            if let notice = notices[space] {
                SpaceNameNoticeCaption(notice: notice)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func hasOverrides(_ space: SpaceID) -> Bool {
        model.config.settings.spaceOverrideCount(for: space) > 0
    }
}
