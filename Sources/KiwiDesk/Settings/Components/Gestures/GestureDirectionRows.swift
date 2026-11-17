import KiwiDeskCore
import SwiftUI

/// An open row's directions (#3199 ▸ Ruling): a hairline rail
/// in the disclosure's slot, then one sub-row per direction on the
/// row's own columns — the arrow under the icon, the name under the
/// gesture pop-up, the action under the row's, the row's keys
/// echoed under its recorder. While the row binds
/// a family each arm reads in secondary text and stays a live
/// picker; picking one arm splits the row, which then reads "Per
/// direction". A swipe lists its two axes first, each followed by
/// its directions while open, all at the SAME one indent (#1873 ▸
/// Ruling 2026-11-15, owner): the order and the labels carry the
/// hierarchy, never a deeper indent or a second rail.
struct GestureDirectionRows: View {
    @ObservedObject var model: SettingsModel
    let key: GestureKey
    let catalog: SequenceActionCatalog
    /// The row's gesture pop-up width.
    let nameWidth: CGFloat
    /// The axes whose directions show.
    @State private var openAxes: Set<GestureAxis> = []

    /// An axis split into fixed directions opens on appear, as a
    /// split row does.
    private func splitAxes() -> Set<GestureAxis> {
        let action = GestureListEdits.action(
            of: key,
            in: model.config.gesture
        )
        guard case .split(let split) = action else { return [] }
        return Set(
            GestureAxis.allCases.filter { axis in
                axis.directions.contains { split.arms[$0] != nil }
            }
        )
    }

    private func openBinding(_ axis: GestureAxis) -> Binding<Bool> {
        Binding(
            get: { openAxes.contains(axis) },
            set: { open in
                if open {
                    openAxes.insert(axis)
                } else {
                    openAxes.remove(axis)
                }
            }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: GestureListRow.columnGap) {
            SettingsTheme.hairlineSubtle
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(width: GestureListRow.disclosureWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if GestureListEdits.splitsByAxis(key.input) {
                    ForEach(GestureAxis.allCases, id: \.self) { axis in
                        GestureAxisRow(
                            model: model,
                            key: key,
                            axis: axis,
                            catalog: catalog,
                            nameWidth: nameWidth,
                            open: openBinding(axis)
                        )
                        if openAxes.contains(axis) {
                            directionRows(axis.directions)
                        }
                    }
                } else {
                    directionRows(key.input.directions)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { openAxes.formUnion(splitAxes()) }
    }

    private func directionRows(
        _ directions: [GestureDirection]
    ) -> some View {
        ForEach(directions, id: \.self) { direction in
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

/// One direction of a gesture row: its arrow, its name, and the
/// action it runs, picked from the whole catalogue, an app or Lua
/// (#3321).
struct GestureDirectionRow: View {
    @ObservedObject var model: SettingsModel
    let key: GestureKey
    let direction: GestureDirection
    let catalog: SequenceActionCatalog
    let nameWidth: CGFloat

    @State var picking: SequencePickRequest?
    @State var choosingApp = false
    @State var editingLua: LuaEditRequest?
    @State var id = UUID()

    var action: GestureAction? {
        GestureListEdits.action(of: key, in: model.config.gesture)
    }

    var body: some View {
        HStack(spacing: GestureListRow.columnGap) {
            GlyphImage(GestureListWords.direction(symbol: direction))
                .foregroundStyle(SettingsTheme.ink2)
                .frame(width: GestureIcon.width)
                .accessibilityHidden(true)
            Text(GestureListWords.direction(direction))
                .frame(width: nameWidth, alignment: .leading)
            actionContainer
            Spacer(minLength: 0)
            heldKeys
            AppRuleDeleteButton.slot
        }
    }

    /// The parent row's keys, echoed in its recorder column (#3281,
    /// owner; ui-designer): plain text, never a well, so it cannot
    /// read as an empty or dimmed recorder; the action's spoken
    /// label carries it. A keyless row echoes nothing.
    private var heldKeys: some View {
        KeyRecorderField.footprint.overlay {
            if !key.chord.isEmpty {
                Text(verbatim: ScrollChordGlyphs.text(key.chord))
                    .monospaced()
                    .foregroundStyle(SettingsTheme.ink2)
                    .accessibilityHidden(true)
            }
        }
    }

    var spokenLabel: String {
        let input = GestureListWords.input(key.input)
        let way = GestureListWords.direction(direction)
        guard !key.chord.isEmpty else {
            return L(
                "shortcuts.gestures.direction_action",
                "%1$@, %2$@",
                input,
                way
            )
        }
        return L(
            "shortcuts.gestures.direction_action_chord",
            "%1$@, %2$@, with %3$@",
            input,
            way,
            ScrollChordGlyphs.spoken(key.chord)
        )
    }

    /// Whether the arm is a family's — the row's or its axis's —
    /// not one of its own.
    var inherited: Bool {
        guard let axis = GestureAxis(of: direction) else {
            if case .family = action { return true }
            return false
        }
        return GestureListEdits.family(of: action, on: axis) != nil
    }

    /// The arm's step; a family's reads its catalogue name, else
    /// the arm's own words.
    var face: SequencePickFace {
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
        if let family = familyOfArm,
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

    /// The family this direction steps by: the row's, or its
    /// axis's on a swipe (#1873).
    private var familyOfArm: GestureFamily? {
        if case .family(let family) = action { return family }
        return GestureAxis(of: direction).flatMap {
            GestureListEdits.family(of: action, on: $0)
        }
    }

    /// Edits this direction's arm alone (`GestureListEdits.arm`).
    func pick(_ arm: LuaAction) {
        let saved = GestureListEdits.arm(
            arm,
            toward: direction,
            of: action,
            on: key.input
        )
        GestureListEdits.set(saved, at: key, in: &model.config.gesture)
    }
}
