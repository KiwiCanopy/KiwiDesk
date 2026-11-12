import KiwiDeskCore
import SwiftUI

/// One row of the gesture list a card holds: the key it stands on,
/// and an id that outlives a re-key so the row keeps its place
/// (#3199 ▸ Ruling).
struct GestureListEntry: Identifiable, Equatable {
    let id: UUID
    var key: GestureKey

    init(_ key: GestureKey, id: UUID = UUID()) {
        self.id = id
        self.key = key
    }
}

/// A gesture list row (#3199 ▸ Ruling): disclosure, the gesture's icon,
/// its pop-up and its action, then the keys and the trash on the
/// right, every key on the page in one column. A row with
/// directions opens to a rail of direction sub-rows
/// (`GestureDirectionRows`). Every edit writes the draft's map
/// through `GestureListEdits`.
struct GestureListRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var entry: GestureListEntry
    /// The keys every other row of the card stands on.
    let others: [GestureKey]
    let offered: [GestureInput]
    let catalog: SequenceActionCatalog
    @Binding var open: Set<UUID>
    var armsOnAppear = false
    /// The row now binds nothing the map holds: it stays as pending.
    let onUnbound: () -> Void
    let onRemove: () -> Void

    @State var picking: SequencePickRequest?
    @State var choosingApp = false
    @State var editingLua: LuaEditRequest?
    /// The gesture pop-up's drawn width, the directions' name column,
    /// so their actions line up under the row's.
    @State private var gestureColumn: CGFloat = 0
    /// A gesture pop-up pick refused for the keys another row holds.
    @State var clash: String?

    var key: GestureKey { entry.key }

    var action: GestureAction? {
        GestureListEdits.action(of: key, in: model.config.gesture)
    }

    var isOpen: Bool { open.contains(entry.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: Self.columnGap) {
                    disclosureSlot
                    GestureIcon(input: key.input)
                    gesturePicker
                    actionContainer
                }
                Spacer(minLength: 8)
                reachColumn
                GestureChordRecorder(
                    name: recorderName,
                    chord: key.chord,
                    allowsNone: !key.input.needsModifier,
                    refuse: refusal(of:),
                    onRecord: { rekey(to: GestureKey(key.input, $0)) },
                    armsOnAppear: armsOnAppear
                )
                AppRuleDeleteButton(
                    help: L(
                        "shortcuts.gestures.remove",
                        "Remove gesture"
                    ),
                    sharedFrom: sharedReach
                ) { removal in
                    if action != nil {
                        model.recordRemoval(.gesture, key.spelling, removal)
                    }
                    onRemove()
                }
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.leading, Self.textIndent)
            }
            if isOpen, !key.input.directions.isEmpty {
                GestureDirectionRows(
                    model: model,
                    key: key,
                    catalog: catalog,
                    nameWidth: gestureColumn
                )
            }
        }
    }

    /// Where a caption under the row starts: past the disclosure
    /// and the icon, on the pop-up's edge.
    static let textIndent: CGFloat =
        disclosureWidth + GestureIcon.width + 2 * columnGap
    static let disclosureWidth: CGFloat = 14
    /// The gap between a row's columns, which its direction sub-rows
    /// share so they line up by construction (ui-designer).
    static let columnGap: CGFloat = 6

    /// Filled on a row with directions; empty elsewhere so every
    /// icon lines up.
    @ViewBuilder private var disclosureSlot: some View {
        if key.input.directions.isEmpty {
            Color.clear.frame(width: Self.disclosureWidth, height: 1)
        } else {
            Button {
                if isOpen {
                    open.remove(entry.id)
                } else {
                    open.insert(entry.id)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: Self.disclosureWidth)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsTheme.ink2)
            .accessibilityLabel(
                L(
                    "shortcuts.gestures.directions",
                    "Directions of %1$@",
                    GestureListWords.input(key.input)
                )
            )
            .accessibilityValue(
                isOpen
                    ? L("settings.disclosure.ax_expanded", "expanded")
                    : L("settings.disclosure.ax_collapsed", "collapsed")
            )
        }
    }

    private var gesturePicker: some View {
        Picker(
            GestureListWords.gesture,
            selection: Binding(
                get: { key.input },
                set: { input in rekeyInput(to: input) }
            )
        ) {
            ForEach(offered, id: \.self) { input in
                Text(GestureListWords.input(input)).tag(input)
            }
        }
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .labelsHidden()
        .fixedSize()
        .accessibilityValue(GestureListWords.input(key.input))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            gestureColumn = $0
        }
    }

    /// The recorder names what it binds: the gesture and its action.
    private var recorderName: String {
        L(
            "shortcuts.gestures.recorder_name",
            "%1$@, %2$@",
            GestureListWords.input(key.input),
            actionTitle
        )
    }

    /// Why the row would not fire as it stands — its keys judged
    /// even before an action is picked, a drag's keys included —
    /// else what a row of mixed directions gave up; nil for neither.
    private var hint: String? {
        if let clash { return clash }
        if let refusal = key.refusal ?? action?.refusal(on: key) {
            return GestureRefusalWords.sentence(refusal)
        }
        if let held = GestureListEdits.heldByDrag(
            key,
            in: model.config.gesture
        ) {
            return GestureRefusalWords.sentence(held)
        }
        if case .split = action {
            return GestureListWords.mixedCaption(key.input)
        }
        return nil
    }

    // MARK: - Re-keying

    /// What a recorded chord would clash with or be refused for.
    func refusal(of chord: ScrollChord) -> String? {
        let target = GestureKey(key.input, chord)
        if others.contains(target) {
            return GestureRefusalWords.taken
        }
        if let refusal = target.refusal ?? action?.refusal(on: target) {
            return GestureRefusalWords.sentence(refusal)
        }
        var base = model.config.gesture
        GestureListEdits.remove(key, in: &base)
        return GestureSeeds.shadowRefusal(
            of: target,
            base: base,
            profile: nil
        ).map(GestureRefusalWords.sentence)
    }

    func rekey(to target: GestureKey) {
        clash = nil
        guard target != key, !others.contains(target) else { return }
        if action != nil {
            var map = model.config.gesture
            guard GestureListEdits.rekey(key, to: target, in: &map)
            else { return }
            // The pick moves while the old key still reads (#3225).
            model.carryPick(.gesture, from: key.spelling, to: target.spelling)
            model.config.gesture = map
        }
        entry.key = target
    }

    /// A new gesture keeps the keys, and the action only where the
    /// new gesture takes it; otherwise the row asks for one again.
    private func rekeyInput(to input: GestureInput) {
        let target = GestureKey(input, key.chord)
        clash = nil
        guard target != key else { return }
        guard !others.contains(target) else {
            // The pop-up snaps back; the row says why.
            clash = GestureRefusalWords.taken
            return
        }
        if let action, action.kindFits(input) {
            rekey(to: target)
            return
        }
        if action != nil {
            model.dropGesturePick(key.spelling, shared: sharedReach != nil)
            GestureListEdits.remove(key, in: &model.config.gesture)
        }
        onUnbound()
        entry.key = target
    }
}

extension GestureAction {
    /// Whether this kind of action is one `input` binds at all,
    /// keys aside: a family only where offered, a grab on a drag.
    func kindFits(_ input: GestureInput) -> Bool {
        switch self {
        case .grab: input.isDrag
        case .family(let family): input.families.contains(family)
        case .split: !input.directions.isEmpty
        case .run: input.directions.isEmpty && !input.isDrag
        }
    }
}
