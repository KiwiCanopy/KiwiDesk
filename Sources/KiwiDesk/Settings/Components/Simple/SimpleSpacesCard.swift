import KiwiDeskCore
import SwiftUI

/// Simple's Spaces (#2777 rulings 7–11): a wrapping grid of Space
/// cards, each its own preview, then "+ Add Space". Every Space
/// stays in view; the page grows with the count.
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

    /// The narrowest card, so a line holds as many as fit.
    static let cardMinimum: CGFloat = 240

    var body: some View {
        SimpleCard(title: SettingsDestination.spaces.title, plated: false) {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Self.cardMinimum),
                        spacing: 16,
                        alignment: .top
                    )
                ],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(
                    reorder.displayed(model.config.spaces),
                    id: \.raw
                ) { space in
                    card(space)
                }
                addCard
            }
            .spaceReorderList(reorder)
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

    private func card(_ space: SpaceID) -> some View {
        SimpleSpaceCard(
            model: model,
            reorder: reorder,
            space: space,
            notice: notices[space],
            onNotice: { notices[space] = $0 },
            onDelete: { requestRemove(space) }
        )
        .rowActions { actions(space) }
    }

    /// The add row in a card's place, last in the grid.
    private var addCard: some View {
        SpaceAddRow(spaces: model.takenSpaceNames) {
            model.config.spaces.append($0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 60)
        .overlay(
            RoundedRectangle(cornerRadius: SettingsTheme.sectionRadius)
                .strokeBorder(
                    SettingsTheme.hairline,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }

    /// The card menu: the grip's reorder for the keyboard and
    /// VoiceOver, and the trash's delete.
    @ViewBuilder
    private func actions(_ space: SpaceID) -> some View {
        Button(L("simple.spaces.move_earlier", "Move Earlier")) {
            model.moveSpace(space, by: -1)
        }
        .disabled(!model.canMoveSpace(space, by: -1))
        Button(L("simple.spaces.move_later", "Move Later")) {
            model.moveSpace(space, by: 1)
        }
        .disabled(!model.canMoveSpace(space, by: 1))
        Divider()
        Button(
            L("spaces.context.delete", "Delete"),
            role: .destructive
        ) {
            requestRemove(space)
        }
    }

    private func requestRemove(_ space: SpaceID) {
        if model.config.carriesOverrides(space) {
            pendingDelete = space
        } else {
            model.removeSpace(space)
        }
    }

}
