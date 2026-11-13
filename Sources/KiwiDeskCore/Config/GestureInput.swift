import Foundation

/// One input a gesture binding can take (#3199 ruling): what the
/// hand does, named Lua-first (`gesture.bind("wheel", …)`). Mouse
/// and trackpad share one list, since a binding is the input plus
/// the keys held with it.
public enum GestureInput: String, CaseIterable, Codable, Sendable {
    // Mouse.
    /// Move the pointer with a button held ("Ziehen").
    case drag
    /// Move the pointer with no button held ("Bewegen").
    case hoverMove = "hover_move"
    /// A primary click with keys held.
    case click
    /// A secondary click with keys held.
    case rightClick = "right_click"
    /// The wheel's press, mouse button 2 ("Wheel click").
    case wheelClick = "wheel_click"
    /// Buttons 3 (back) and 4 (forward).
    case sideButtons = "side_buttons"
    /// A scroll with no finger phase on the vertical axis.
    case wheel
    /// A scroll with no finger phase on the horizontal axis: a
    /// tilt or thumb wheel.
    case wheelX = "wheel_x"
    // Trackpad.
    case tap2, tap3, tap4, tap5
    /// A scroll with a finger phase (trackpad, Magic Mouse) — the
    /// two-finger swipe the pan rides on (#3200).
    case swipe2
    case swipe3, swipe4, swipe5
    // Stored, never fired until #2447 reads them.
    case spread
    case pinchTogether = "pinch_together"
    case rotate
    case forceClick = "force_click"

    public enum Device: Sendable { case mouse, trackpad }

    public var device: Device {
        switch self {
        case .drag, .hoverMove, .click, .rightClick, .wheelClick,
            .sideButtons, .wheel, .wheelX:
            .mouse
        default: .trackpad
        }
    }

    /// The directions one motion of this input names; empty for an
    /// input with none (a click, a tap).
    public var directions: [GestureDirection] {
        switch self {
        case .swipe2, .swipe3, .swipe4, .swipe5:
            [.up, .down, .left, .right]
        case .wheel: [.up, .down]
        case .wheelX: [.left, .right]
        case .sideButtons: [.back, .forward]
        default: []
        }
    }

    /// A pointer motion holds the window while the keys are down,
    /// so it binds a grab alone (#3199 amendment).
    public var isDrag: Bool { self == .drag || self == .hoverMove }

    /// Whether the grab starts on a press or on the keys alone.
    public var grabStart: ModifierDragStart? {
        switch self {
        case .drag: .drag
        case .hoverMove: .hover
        default: nil
        }
    }

    /// A scroll the tap reads with a finger phase (#3200).
    public var isPhasedScroll: Bool { self == .swipe2 }

    /// A scroll the tap reads with no phase.
    public var isWheel: Bool { self == .wheel || self == .wheelX }

    /// A press of a mouse button, which the pointer tap fires.
    public var isButton: Bool {
        switch self {
        case .click, .rightClick, .wheelClick, .sideButtons: true
        default: false
        }
    }

    /// Every input but a tap, the wheel click and the side buttons
    /// needs a held key: macOS and apps own the bare gesture.
    public var needsModifier: Bool {
        switch self {
        case .tap2, .tap3, .tap4, .tap5, .sideButtons, .wheelClick:
            false
        default: true
        }
    }

    /// The families this input offers (#3199 ▸ Families by
    /// input): a swipe every family, a wheel the walk and
    /// the Space step, the side buttons the directional ones.
    public var families: [GestureFamily] {
        switch self {
        case .swipe2: GestureFamily.allCases
        case .swipe3, .swipe4, .swipe5:
            [.focus, .swap, .display, .track, .space, .walk]
        case .wheel, .wheelX: [.walk, .space]
        case .sideButtons: [.focus, .space]
        default: []
        }
    }

    /// The finger count of a touch input; nil for the others.
    public var fingers: Int? {
        switch self {
        case .tap2, .swipe2: 2
        case .tap3, .swipe3: 3
        case .tap4, .swipe4: 4
        case .tap5, .swipe5: 5
        default: nil
        }
    }

    /// One of macOS's own gesture events, which only a tap with the
    /// gesture-event mask can swallow (#2447's `PointerTap`); no
    /// reader exists for these yet.
    public var isGestureEvent: Bool {
        switch self {
        case .spread, .pinchTogether, .rotate, .forceClick: true
        default: false
        }
    }

    /// Whether a front fires this input today: the pointer tap
    /// fires the drags, the clicks and the side buttons (#3281), the
    /// scroll tap the wheels and the pan; a two-finger tap waits for
    /// the touch router, the pinches and Force Click for #2447.
    public var isFired: Bool {
        switch self {
        case .drag, .hoverMove, .wheel, .wheelX, .swipe2: true
        case _ where isButton: true
        case .tap2, .tap3, .tap4, .tap5, .swipe3, .swipe4, .swipe5:
            fingers.map(TrackpadGestureRouter.fingerRange.contains) ?? false
        default: false
        }
    }

    static func tap(fingers: Int) -> GestureInput? {
        allCases.first { $0.rawValue == "tap\(fingers)" }
    }

    static func swipe(fingers: Int) -> GestureInput? {
        allCases.first { $0.rawValue == "swipe\(fingers)" }
    }
}

/// One direction of a motion: the fingers' or the wheel's, or a
/// side button. Stored as the hand moves — ↑ is fingers up —
/// whatever Natural scrolling says (#3200 amendment).
public enum GestureDirection: String, CaseIterable, Codable, Sendable {
    case up, down, left, right
    /// Side button 3.
    case back
    /// Side button 4.
    case forward

    /// The layout direction a directional family steps toward.
    var layout: Direction {
        switch self {
        case .up: .up
        case .down: .down
        case .left, .back: .left
        case .right, .forward: .right
        }
    }

    /// Up, left and back step toward the start of a list.
    var isBackward: Bool { self == .up || self == .left || self == .back }

    /// A side button: a press, not a motion, so a list family steps
    /// the way the button is named (Back = previous) and no Natural
    /// scrolling reaches it.
    var isButton: Bool { self == .back || self == .forward }
}
