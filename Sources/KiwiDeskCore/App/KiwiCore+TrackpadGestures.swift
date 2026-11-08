import Foundation

/// Where the trackpad gesture slots reach the touch reader, and
/// where a recognized gesture runs its action (#1873).
extension KiwiCore {
    /// Wires the handler; once, at bootstrap. A slot's action runs
    /// as a shortcut press does, so its motion is the user's.
    func wireTrackpadGestures() {
        mouse.touch.setHandler { [weak self] slot, binding, event in
            self?.runTrackpadGesture(slot, binding, event)
        }
    }

    func runTrackpadGesture(
        _ slot: TrackpadGestureSlot,
        _ binding: TrackpadGestureBinding,
        _ event: TrackpadGestureEvent
    ) {
        guard let code = Self.trackpadGestureLua(binding, event) else {
            return
        }
        if case .failure(let error) = keys.firePress(code) {
            onLog("trackpad_gesture \(slot.rawValue): \(error)")
        }
    }

    /// The Lua one gesture runs: a swipe's family with its
    /// direction, any other slot's action as written.
    static func trackpadGestureLua(
        _ binding: TrackpadGestureBinding,
        _ event: TrackpadGestureEvent
    ) -> String? {
        switch event.kind {
        case .tap: return binding.action
        case .swipe(let direction):
            return TrackpadSwipeFamily(rawValue: binding.action)?
                .lua(direction)
        }
    }

    /// The ONE resolve: the seeds, the base over them and the live
    /// profile's override on top, handed to the front's one door.
    /// A config load passes the base it read; a profile apply
    /// passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua`'s verbs declared.
    func applyTrackpadGestures(
        base: TrackpadGestureMap? = nil,
        profile: TrackpadGestureMap?
    ) {
        mouse.touch.adoptResolution(
            base: base ?? mouse.touch.base,
            profileOverride: profile
        )
    }

    /// `trackpad_gesture.bind(slot, action, modifiers)`: writes the
    /// BASE, so a profile's own override still wins, and lasts
    /// until the next config load. An empty or missing action is
    /// None, turning a seeded slot off. No window moves.
    func trackpadGestureCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command == "trackpad_gesture.bind" else {
            return .fail("unknown command: \(command)")
        }
        guard let raw = args.first?.stringValue else {
            return .fail("expected a gesture slot")
        }
        guard let slot = TrackpadGestureSlot(rawValue: raw) else {
            return .expected(TrackpadGestureSlot.self)
        }
        var base = mouse.touch.base
        let action = args.dropFirst().first?.stringValue ?? ""
        if action.isEmpty {
            base[slot] = .unbound
        } else {
            let spelling = args.dropFirst(2).first?.stringValue ?? ""
            guard let modifiers = ScrollChord(spelling: spelling) else {
                return .fail(
                    "expected modifiers like \"control+option\""
                )
            }
            let binding = TrackpadGestureBinding(
                action: action,
                modifiers: modifiers
            )
            switch binding.refusal(on: slot) {
            case nil: break
            case .emptyAction: return .fail("expected an action")
            case .needsModifier:
                return .fail("\(slot.rawValue) needs a modifier")
            case .unknownFamily:
                return .expected(TrackpadSwipeFamily.self)
            }
            base[slot] = .bound(binding)
        }
        applyTrackpadGestures(
            base: base,
            profile: mouse.touch.profileOverride
        )
        return .ok()
    }
}
