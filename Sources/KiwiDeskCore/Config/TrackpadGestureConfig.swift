import Foundation

/// What one gesture slot does (#1873): the modifiers held with it
/// and the action — Lua for a tap or a pinch, a
/// `TrackpadSwipeFamily` name for a swipe.
public struct TrackpadGestureBinding: Equatable, Sendable {
    public var action: String
    public var modifiers: ScrollChord

    public init(action: String, modifiers: ScrollChord = []) {
        self.action = action
        self.modifiers = modifiers
    }
}

/// Why a binding is refused for its slot. Core names it; the CLI
/// and a future Settings row each word it.
public enum TrackpadGestureRefusal: Equatable, Sendable {
    case emptyAction
    case needsModifier
    case unknownFamily
}

extension TrackpadGestureBinding {
    /// The refusal for this binding on `slot`, nil when it stands.
    public func refusal(
        on slot: TrackpadGestureSlot
    ) -> TrackpadGestureRefusal? {
        if action.trimmingCharacters(in: .whitespaces).isEmpty {
            return .emptyAction
        }
        if slot.needsModifier, modifiers.isEmpty {
            return .needsModifier
        }
        if slot.isSwipe, TrackpadSwipeFamily(rawValue: action) == nil {
            return .unknownFamily
        }
        return nil
    }
}

/// One stored slot: a binding, or `unbound` — the tombstone that
/// turns a seeded or inherited slot off (`null` on the wire).
public enum TrackpadGestureEntry: Equatable, Sendable {
    case bound(TrackpadGestureBinding)
    case unbound

    var binding: TrackpadGestureBinding? {
        if case .bound(let binding) = self { return binding }
        return nil
    }
}

/// A sparse slot map (#1873 ruling ▸ Storage): a slot it does not
/// name inherits. The same shape stores the global base in
/// `gui.json`, laid over the seeds, and a profile's override, laid
/// over the base; `unbound` is None at either level.
public struct TrackpadGestureMap: Equatable, Sendable {
    public var entries: [TrackpadGestureSlot: TrackpadGestureEntry]

    public init(
        _ entries: [TrackpadGestureSlot: TrackpadGestureEntry] = [:]
    ) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }

    public subscript(slot: TrackpadGestureSlot) -> TrackpadGestureEntry? {
        get { entries[slot] }
        set { entries[slot] = newValue }
    }
}

/// The seeded slots and the one resolve (#1873 ruling ▸ Seeded
/// defaults). A slot the stored base leaves out follows the seed,
/// so a seed a later release adds reaches an install that never
/// touched that slot.
public enum TrackpadGestureSeeds {
    private static let hyper: ScrollChord = [.control, .option]

    /// ⌃⌥ pinch together waits for #1229's Desktop overview, which
    /// seeds it with its own verb.
    public static let seeds: [TrackpadGestureSlot: TrackpadGestureBinding] = [
        .rotate: .init(action: "KiwiDesk.cycle_mode()", modifiers: hyper),
        .spread: .init(
            action: "KiwiDesk.toggle_maximized()",
            modifiers: hyper
        ),
        .tap4: .init(action: KiwiHubSide.shortcuts.lua),
        .tap3: .init(action: "KiwiDesk.focus_space_last()"),
    ]

    /// The bound slots once `base` lies over the seeds and
    /// `profile` over that; a refused binding is dropped, since a
    /// hand-edited file reaches what the verb refuses.
    public static func resolved(
        base: TrackpadGestureMap,
        profile: TrackpadGestureMap?
    ) -> [TrackpadGestureSlot: TrackpadGestureBinding] {
        var out = seeds
        for layer in [base, profile ?? TrackpadGestureMap()] {
            for (slot, entry) in layer.entries {
                out[slot] = entry.binding
            }
        }
        return out.filter { $0.value.refusal(on: $0.key) == nil }
    }
}
