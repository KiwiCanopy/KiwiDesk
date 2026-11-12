import KiwiDeskCore
import SwiftUI

/// A gesture row's action picker (#3199 ▸ Ruling): the one
/// `SequenceActionMenu`, handed the pins the gesture binds — a
/// swipe's or a scroll's families and "Per direction", a drag's
/// grabs — and the whole catalogue only where the gesture runs one
/// action.
extension GestureListRow {
    var actionMenu: some View {
        SequenceActionMenu(
            face: face,
            catalog: catalog,
            spokenLabel: L(
                "shortcuts.gestures.action_name",
                "Action for %1$@",
                GestureListWords.input(key.input)
            ),
            pins: pins,
            showsCatalogue: offersCatalogue,
            onPick: { bind(GestureListEdits.action(picking: $0)) },
            onApp: appDoor,
            onLua: luaDoor,
            onEditLua: editLuaDoor,
            request: $picking
        )
    }

    /// App… and Lua…, offered only where the row runs one action.
    private var appDoor: (() -> Void)? {
        guard offersCatalogue else { return nil }
        return { choosingApp = true }
    }

    private var luaDoor: (() -> Void)? {
        guard offersCatalogue else { return nil }
        return { startLua() }
    }

    private var editLuaDoor: (() -> Void)? {
        guard offersCatalogue else { return nil }
        return { editingLua = LuaEditRequest(id: entry.id) }
    }

    /// A gesture with directions or a grab picks from its pins
    /// alone; any other runs one action from the catalogue.
    var offersCatalogue: Bool {
        key.input.directions.isEmpty && !key.input.isDrag
    }

    var actionTitle: String {
        switch action {
        case nil: GestureListWords.chooseAction
        case .family(let family): GestureListWords.family(family)
        case .split: GestureListWords.perDirection
        case .grab(let grab): GestureListWords.grab(grab)
        case .run(let run):
            catalog.command(running: run.lua)?.resolvedLabel
                ?? run.meta.desc.nonEmpty ?? run.lua
        }
    }

    /// The trigger's face: a command reads the catalogue; a family,
    /// a split, a grab or nothing yet reads its own words.
    var face: SequencePickFace {
        if case .run(let run) = action {
            return SequencePickFace(
                id: entry.id,
                kind: run.kind,
                lua: run.lua,
                desc: run.meta.desc
            )
        }
        return SequencePickFace(
            id: entry.id,
            kind: .navigation,
            lua: "",
            title: actionTitle
        )
    }

    var pins: [SequencePickPin] {
        if key.input.isDrag {
            return ModifierDragAction.allCases.map { grab in
                SequencePickPin(
                    id: grab.rawValue,
                    label: GestureListWords.grab(grab),
                    symbol: grab == .move
                        ? "arrow.up.and.down.and.arrow.left.and.right"
                        : "arrow.up.left.and.arrow.down.right",
                    picked: action == .grab(grab)
                ) { bind(.grab(grab)) }
            }
        }
        // The directions open through the disclosure alone, never a
        // pinned entry (#3199 ▸ Ruling amendment: directions without
        // a split button).
        return key.input.families.map { family in
            SequencePickPin(
                id: family.rawValue,
                label: GestureListWords.family(family),
                symbol: "arrow.left.arrow.right",
                picked: action == .family(family)
            ) { bind(.family(family)) }
        }
    }

    /// Binds `action` on the row's key; a family folds the arms
    /// back into one. The directions stay as open as they were.
    func bind(_ action: GestureAction) {
        GestureListEdits.set(action, at: key, in: &model.config.gesture)
    }
}

extension String {
    /// Self, or nil when blank.
    fileprivate var nonEmpty: String? { trimmed.isEmpty ? nil : self }
}

/// A row's gesture icon (#3199 ▸ Ruling): the gesture's symbol, a
/// swipe or a tap carrying its finger count as a badge.
struct GestureIcon: View {
    let input: GestureInput
    static let width: CGFloat = 26

    var body: some View {
        Image(systemName: GestureListWords.symbol(input))
            .font(.body)
            .foregroundStyle(SettingsTheme.ink2)
            .frame(width: Self.width, height: 20)
            .overlay(alignment: .bottomTrailing) {
                if let fingers = input.fingers {
                    Text(verbatim: "\(fingers)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SettingsTheme.ink)
                        .padding(.horizontal, 3)
                        .background(
                            Capsule().fill(SettingsTheme.chipRest)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityHidden(true)
    }
}
