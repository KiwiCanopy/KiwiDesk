import Foundation

/// One fixed trackpad gesture a binding can take (#1873 ruling
/// 2026-11-08). The raw values are the Lua and JSON names, chosen
/// Lua-first: `trackpad_gesture.bind("tap4", …)`.
public enum TrackpadGestureSlot: String, CaseIterable, Codable, Sendable {
    case tap3, tap4, tap5
    case swipe3, swipe4, swipe5
    /// Fingers moving apart.
    case spread
    /// Fingers closing.
    case pinchTogether = "pinch_together"
    case rotate
    case forceClick = "force_click"

    /// Where a slot's input comes from.
    public enum Source: Sendable {
        /// Raw finger frames from MultitouchSupport (`TouchReader`).
        case touches
        /// macOS's own gesture events, which only a tap with the
        /// gesture-event mask can swallow (#2447's `PointerTap`).
        /// No reader exists for these yet: a binding is stored and
        /// resolved, and nothing fires it.
        case gestureEvents
    }

    public var source: Source {
        switch self {
        case .tap3, .tap4, .tap5, .swipe3, .swipe4, .swipe5:
            return .touches
        case .spread, .pinchTogether, .rotate, .forceClick:
            return .gestureEvents
        }
    }

    /// The finger count a touch slot reads; nil for the others.
    public var fingers: Int? {
        switch self {
        case .tap3, .swipe3: return 3
        case .tap4, .swipe4: return 4
        case .tap5, .swipe5: return 5
        default: return nil
        }
    }

    /// A swipe binds a directional family; every other slot a Lua
    /// action.
    public var isSwipe: Bool {
        self == .swipe3 || self == .swipe4 || self == .swipe5
    }

    /// Whether a binding must hold a modifier: every slot but the
    /// taps, since macOS and apps own the unmodified gestures
    /// (Preview, Photos and Maps rotate and pinch themselves).
    public var needsModifier: Bool {
        switch self {
        case .tap3, .tap4, .tap5: return false
        default: return true
        }
    }

    /// The tap slot for `fingers`, the swipe slot likewise.
    static func tap(fingers: Int) -> TrackpadGestureSlot? {
        allCases.first {
            !$0.isSwipe && $0.source == .touches && $0.fingers == fingers
        }
    }

    static func swipe(fingers: Int) -> TrackpadGestureSlot? {
        allCases.first { $0.isSwipe && $0.fingers == fingers }
    }
}

/// The directional families a swipe slot binds; the swipe's
/// direction supplies the argument (#1873 ruling). `move_to_space`
/// and `desktop` wait for a relative target their verbs do not
/// take yet.
public enum TrackpadSwipeFamily: String, CaseIterable, Codable, Sendable {
    case focus, swap, display, track, space

    /// The Lua one swipe runs. Fingers moving left reach the
    /// window, screen or track on the left; a Space step follows
    /// macOS's Desktop swipe, where fingers moving left show the
    /// next one.
    func lua(_ direction: Direction) -> String {
        switch self {
        case .focus: return "KiwiDesk.focus(\"\(direction.rawValue)\")"
        case .swap: return "KiwiDesk.swap(\"\(direction.rawValue)\")"
        case .display:
            return "KiwiDesk.focus_display(\"\(direction.rawValue)\")"
        case .track:
            let back = direction == .left || direction == .up
            let step = back ? "prev" : "next"
            return "KiwiDesk.move_to_track(\"\(step)\")"
        case .space:
            return direction == .left || direction == .up
                ? "KiwiDesk.focus_space_next()"
                : "KiwiDesk.focus_space_previous()"
        }
    }
}
