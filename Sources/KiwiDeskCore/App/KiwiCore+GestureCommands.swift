import Foundation

/// `gesture.bind(input, keys, action)` and `gesture.unbind(input,
/// keys)` (#3199): they write the running BASE, so a profile's own
/// override still wins, and last until the next config load. No
/// window moves.
extension KiwiCore {
    func gestureCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected a gesture")
        }
        guard let input = GestureInput(rawValue: raw) else {
            return .expected(GestureInput.self)
        }
        let spelling = args.dropFirst().first?.stringValue ?? ""
        guard let keys = ScrollChord(spelling: spelling) else {
            return .fail("expected keys like \"control+option\", or \"\"")
        }
        let key = GestureKey(input, keys)
        var base = mouse.gestures.base
        switch command {
        case "gesture.unbind":
            base[key] = .unbound
        case "gesture.bind":
            guard let action = Self.gestureAction(args.dropFirst(2).first)
            else {
                return .fail(
                    "expected a family, \"move\" or \"resize\", Lua, "
                        + "or a table of directions"
                )
            }
            if let refusal = action.refusal(on: key) {
                return .fail(Self.gestureRefusal(refusal, key))
            }
            base[key] = .bound(action)
            if let refusal = GestureSeeds.shadowRefusal(
                of: key,
                base: base,
                profile: mouse.gestures.profileOverride
            ) {
                return .fail(Self.gestureRefusal(refusal, key))
            }
        default:
            return .fail("unknown command: \(command)")
        }
        applyGestures(
            base: base,
            profile: mouse.gestures.profileOverride,
            scrollProfile: mouse.scroll.profileOverride
        )
        return .ok()
    }

    /// An action argument: a family or grab name, Lua, or a table
    /// of direction → Lua (a split).
    static func gestureAction(_ arg: JSONValue?) -> GestureAction? {
        if let text = arg?.stringValue {
            if let family = GestureFamily(rawValue: text) {
                return .family(family)
            }
            if let grab = ModifierDragAction(rawValue: text) {
                return .grab(grab)
            }
            return text.isEmpty ? nil : .run(LuaAction(lua: text))
        }
        guard case .object(let table)? = arg else { return nil }
        var arms: [GestureDirection: LuaAction] = [:]
        for (name, value) in table {
            guard let direction = GestureDirection(rawValue: name),
                let lua = value.stringValue, !lua.isEmpty
            else { return nil }
            arms[direction] = LuaAction(lua: lua)
        }
        return .split(normalizing: arms)
    }

    /// A refusal in CLI English.
    static func gestureRefusal(
        _ refusal: GestureRefusal,
        _ key: GestureKey
    ) -> String {
        let input = key.input.rawValue
        switch refusal {
        case .emptyAction: return "expected an action"
        case .needsModifier: return "\(input) needs a modifier"
        case .singleModifierScroll:
            return "a scroll needs two or more modifiers"
        case .shiftOnWheel:
            return "a wheel cannot use shift: macOS makes it sideways"
        case .familyNotOffered:
            return "\(input) takes "
                + key.input.families.map(\.rawValue).joined(separator: ", ")
        case .grabOnlyOnDrag:
            return "only drag and hover_move take move or resize, "
                + "and they take nothing else"
        case .directionalNeedsFamily:
            return "\(input) takes a family or a table of directions"
        case .noDirections:
            return "\(input) has no such direction"
        case .keysHeldByDrag:
            return "a click or hover_move cannot share a drag's keys"
        }
    }
}
