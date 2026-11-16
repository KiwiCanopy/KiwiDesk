import KiwiDeskCore
import SwiftUI

/// One axis of a swipe row (#1873 ▸ Ruling 2026-11-15, preview
/// `split-editor-v2`): its disclosure, its two-way arrow, its name
/// and a family picker, at the direction rows' one indent. Picking
/// a family folds the axis's two directions back into it without
/// asking; picking an action on a direction splits the axis, which
/// then reads "Per direction". There is no level control.
struct GestureAxisRow: View {
    @ObservedObject var model: SettingsModel
    let key: GestureKey
    let axis: GestureAxis
    let catalog: SequenceActionCatalog
    let nameWidth: CGFloat
    @Binding var open: Bool

    @State private var picking: SequencePickRequest?
    @State private var id = UUID()

    private var action: GestureAction? {
        GestureListEdits.action(of: key, in: model.config.gesture)
    }

    private var family: GestureFamily? {
        GestureListEdits.family(of: action, on: axis)
    }

    var body: some View {
        HStack(spacing: GestureListRow.columnGap) {
            disclosure
            Image(systemName: GestureListWords.axis(symbol: axis))
                .foregroundStyle(SettingsTheme.ink2)
                .frame(width: GestureIcon.width)
                .accessibilityHidden(true)
            Text(GestureListWords.axis(axis))
                .frame(width: nameWidth, alignment: .leading)
            menu
            Spacer(minLength: 0)
            KeyRecorderField.footprint
            AppRuleDeleteButton.slot
        }
    }

    private var disclosure: some View {
        Button {
            open.toggle()
        } label: {
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(open ? 90 : 0))
                .frame(width: GestureListRow.disclosureWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(SettingsTheme.ink2)
        .accessibilityLabel(GestureListWords.axisDirections(axis))
        .accessibilityValue(
            open
                ? L("settings.disclosure.ax_expanded", "expanded")
                : L("settings.disclosure.ax_collapsed", "collapsed")
        )
    }

    private var menu: some View {
        SequenceActionMenu(
            face: SequencePickFace(
                id: id,
                kind: .navigation,
                lua: "",
                title: family.map(GestureListWords.family)
                    ?? GestureListWords.perDirection(key.input)
            ),
            catalog: catalog,
            spokenLabel: L(
                "shortcuts.gestures.axis_action",
                "%1$@, %2$@",
                GestureListWords.input(key.input),
                GestureListWords.axis(axis)
            ),
            pins: key.input.families.map { family in
                SequencePickPin(
                    id: family.rawValue,
                    title: GestureListWords.family(family),
                    symbol: ShortcutsReferenceBuilder.familyIcon(
                        for: family
                    ),
                    picked: self.family == family
                ) { pick(family) }
            },
            showsCatalogue: false,
            onPick: { _ in },
            onApp: nil,
            onLua: nil,
            onEditLua: nil,
            request: $picking
        )
        .foregroundStyle(
            isWhole ? SettingsTheme.ink2 : SettingsTheme.ink
        )
    }

    /// While the row binds one family the axis reads in secondary
    /// ink, as its directions do.
    private var isWhole: Bool {
        if case .family = action { return true }
        return false
    }

    private func pick(_ family: GestureFamily) {
        guard
            let saved = GestureListEdits.axis(
                axis,
                family: family,
                of: action,
                on: key.input
            )
        else { return }
        GestureListEdits.set(saved, at: key, in: &model.config.gesture)
    }
}
