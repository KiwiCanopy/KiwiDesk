import Foundation

/// One physical modifier key: Right ⌘, Left ⌥.
public struct ModifierKey: Hashable, Sendable {
    public var kind: ModifierKind
    public var side: ModifierSide

    public init(_ kind: ModifierKind, _ side: ModifierSide) {
        self.kind = kind
        self.side = side
    }

    /// The one physical modifier `held` (from
    /// `HotkeyModifiers.held(by:)`) holds, nil for none or several.
    static func alone(in held: HotkeyModifiers) -> ModifierKey? {
        let kinds = ModifierKind.allCases.filter {
            held.contains($0.plain)
        }
        guard kinds.count == 1, let kind = kinds.first else {
            return nil
        }
        let sides = ModifierSide.allCases.filter {
            held.contains(.side($0, of: kind))
        }
        guard sides.count == 1, let side = sides.first else {
            return nil
        }
        return ModifierKey(kind, side)
    }
}

/// A modifier tapped alone, once or twice (#1872).
public struct ModifierTap: Hashable, Sendable {
    public var key: ModifierKey
    public var count: Int

    public init(_ key: ModifierKey, count: Int) {
        self.key = key
        self.count = count
    }

    /// The binding this tap spells, sided: a reader matching it
    /// against an either-side binding compares `unsided`.
    public var combo: KeyCombo? {
        KeyCombo.tap(key.kind, side: key.side, count: count)
    }
}

/// The one rule that tells a modifier tap (#1872, #1229 ▸
/// Detection), shared by the recorder and the trigger so what
/// records is what fires. Each press is under `pressLimit` with
/// nothing between press and release; a second press of the SAME
/// key comes within `gapLimit` of the first release; any key,
/// click or other modifier in between ends the count. At most two
/// taps. A single tap is decided once no second can come: at the
/// release where `immediate` names the key, else when the caller
/// hands back the `pending` token after `gapLimit`.
///
/// Pure and clock-free: the caller supplies each event's time in
/// seconds, from one clock, and owns the gap timer.
public struct ModifierTapDetector: Sendable {
    public static let pressLimit: TimeInterval = 0.25
    public static let gapLimit: TimeInterval = 0.3

    public enum Input: Sendable {
        /// The modifiers now held, sides included, at a time.
        case flags(HotkeyModifiers, at: TimeInterval)
        /// A non-modifier key went down.
        case key
        /// A mouse button went down.
        case mouseDown
    }

    public struct Output: Equatable, Sendable {
        public var taps: [ModifierTap] = []
        /// A single tap of `key` waits on `token`: hand it to
        /// `expire` after `gapLimit`.
        public var pending: Pending?
    }

    /// A single tap waiting out the gap.
    public struct Pending: Equatable, Sendable {
        public var token: UInt64
        public var key: ModifierKey
    }

    /// Keys whose single tap needs no wait: no double tap is
    /// listened for on them. Empty for the recorder.
    public var immediate: Set<ModifierKey> = []

    private var held: HotkeyModifiers = []
    private var press: (key: ModifierKey, at: TimeInterval)?
    private var first: (key: ModifierKey, released: TimeInterval)?
    private var token: UInt64 = 0

    public init(immediate: Set<ModifierKey> = []) {
        self.immediate = immediate
    }

    public mutating func feed(_ input: Input) -> Output {
        guard case .flags(let now, let time) = input else {
            reset()
            return Output()
        }
        let previous = held
        held = now
        guard now != previous else { return Output() }
        let was = ModifierKey.alone(in: previous)
        let pressed = ModifierKey.alone(in: now)
        if previous.unsided.isEmpty, let pressed {
            return began(pressed, at: time)
        }
        if now.unsided.isEmpty, let was, press?.key == was {
            return released(was, at: time)
        }
        reset()
        return Output()
    }

    /// The single tap `token` waited on, if nothing since ended it.
    public mutating func expire(_ token: UInt64) -> ModifierTap? {
        guard token == self.token, press == nil, let first else {
            return nil
        }
        self.first = nil
        return ModifierTap(first.key, count: 1)
    }

    private mutating func began(
        _ key: ModifierKey,
        at time: TimeInterval
    ) -> Output {
        // A press stops the gap timer either way.
        token &+= 1
        press = (key, time)
        guard let first else { return Output() }
        if time - first.released > Self.gapLimit {
            // The gap ran out before a late timer said so: the
            // single tap was whole, whichever key comes next.
            self.first = nil
            return Output(taps: [ModifierTap(first.key, count: 1)])
        }
        if first.key != key { self.first = nil }
        return Output()
    }

    private mutating func released(
        _ key: ModifierKey,
        at time: TimeInterval
    ) -> Output {
        defer { press = nil }
        guard let press, time - press.at < Self.pressLimit else {
            first = nil
            return Output()
        }
        if first?.key == key {
            first = nil
            return Output(taps: [ModifierTap(key, count: 2)])
        }
        if immediate.contains(key) {
            return Output(taps: [ModifierTap(key, count: 1)])
        }
        first = (key, time)
        token &+= 1
        return Output(pending: Pending(token: token, key: key))
    }

    private mutating func reset() {
        press = nil
        first = nil
        token &+= 1
    }
}
