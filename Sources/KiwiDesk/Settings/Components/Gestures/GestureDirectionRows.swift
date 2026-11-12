import KiwiDeskCore
import SwiftUI

/// An open row's directions (#3183 ▸ Directions): a hairline rail
/// in the disclosure's slot, then one sub-row per direction on the
/// row's own columns — the arrow under the icon, the name under the
/// gesture pop-up, the action under the row's. While the row binds
/// a family each arm reads in secondary text and stays a live
/// picker; picking one arm splits the row, which then reads "Per
/// direction".
struct GestureDirectionRows: View {
    @ObservedObject var model: SettingsModel
    let key: GestureKey
    let catalog: SequenceActionCatalog
    /// The row's gesture pop-up width.
    let nameWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: GestureListRow.columnGap) {
            SettingsTheme.hairlineSubtle
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(width: GestureListRow.disclosureWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(key.input.directions, id: \.self) { direction in
                    GestureDirectionRow(
                        model: model,
                        key: key,
                        direction: direction,
                        catalog: catalog,
                        nameWidth: nameWidth
                    )
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One direction of a gesture row: its arrow, its name, and the
/// action it runs, picked from the whole catalogue.
struct GestureDirectionRow: View {
    @ObservedObject var model: SettingsModel
    let key: GestureKey
    let direction: GestureDirection
    let catalog: SequenceActionCatalog
    let nameWidth: CGFloat

    @State private var picking: SequencePickRequest?
    @State private var id = UUID()

    private var action: GestureAction? {
        GestureListEdits.action(of: key, in: model.config.gesture)
    }

    var body: some View {
        HStack(spacing: GestureListRow.columnGap) {
            Image(systemName: GestureListWords.direction(symbol: direction))
                .foregroundStyle(SettingsTheme.ink2)
                .frame(width: GestureIcon.width)
                .accessibilityHidden(true)
            Text(GestureListWords.direction(direction))
                .frame(width: nameWidth, alignment: .leading)
            SequenceActionMenu(
                face: face,
                catalog: catalog,
                spokenLabel: L(
                    "shortcuts.gestures.direction_action",
                    "%1$@, %2$@",
                    GestureListWords.input(key.input),
                    GestureListWords.direction(direction)
                ),
                pins: [],
                onPick: { command in
                    pick(LuaAction(lua: command.lua, kind: .navigation))
                },
                onApp: {},
                onLua: {},
                onEditLua: {},
                request: $picking
            )
            .foregroundStyle(
                inherited ? SettingsTheme.ink2 : SettingsTheme.ink
            )
            Spacer(minLength: 0)
        }
    }

    /// Whether the arm is the family's, not one of its own.
    private var inherited: Bool {
        if case .family = action { return true }
        return false
    }

    /// The arm's step; a family's reads its catalogue name, else
    /// the arm's own words.
    private var face: SequencePickFace {
        let arm = GestureListEdits.arms(of: action, on: key.input)?[
            direction
        ]
        guard let arm else {
            return SequencePickFace(
                id: id,
                kind: .navigation,
                lua: "",
                title: GestureListWords.chooseAction
            )
        }
        var title: String?
        if case .family(let family) = action,
            catalog.command(running: arm.lua) == nil
        {
            title = GestureListWords.arm(family, toward: direction)
        }
        return SequencePickFace(
            id: id,
            kind: arm.kind,
            lua: arm.lua,
            desc: arm.meta.desc,
            title: title
        )
    }

    /// Edits one arm; arms that all match a family again fold back
    /// into it, which keeps the pan.
    private func pick(_ arm: LuaAction) {
        var arms =
            GestureListEdits.arms(of: action, on: key.input) ?? [:]
        arms[direction] = arm
        guard let saved = GestureListEdits.folded(arms, on: key.input)
        else { return }
        GestureListEdits.set(saved, at: key, in: &model.config.gesture)
    }
}
