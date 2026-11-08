import Foundation

/// Which multi-finger gestures macOS itself answers, read from the
/// trackpad preferences System Settings writes (#1873 ruling ▸
/// Offered). A slot on a gesture macOS owns stays stored and does
/// not fire, since the reader cannot keep macOS from answering it
/// too; a failed read owns nothing, so the binding stays live.
public struct TrackpadSystemGestures: Equatable, Sendable {
    public enum Axis: Sendable { case horizontal, vertical }

    /// Swipe axes macOS answers, per finger count.
    public var swipes: [Int: Set<Axis>]
    /// Whether a three-finger tap is Look up.
    public var lookUpTap: Bool
    /// Whether the read answered at all.
    public var read: Bool

    public init(
        swipes: [Int: Set<Axis>] = [:],
        lookUpTap: Bool = false,
        read: Bool = true
    ) {
        self.swipes = swipes
        self.lookUpTap = lookUpTap
        self.read = read
    }

    public static let unread = TrackpadSystemGestures(read: false)

    /// Whether macOS answers `event` itself.
    func owns(_ event: TrackpadGestureEvent) -> Bool {
        switch event.kind {
        case .tap: return event.fingers == 3 && lookUpTap
        // A gesture event reaches KiwiDesk only through a tap that
        // swallows it, so macOS never answers it as well.
        case .gesture: return false
        case .swipe(let direction):
            let axis: Axis =
                direction == .left || direction == .right
                ? .horizontal : .vertical
            return swipes[event.fingers]?.contains(axis) ?? false
        }
    }

    /// The preference keys. Any value but 0 counts as macOS's: a
    /// swipe key's 1 and 2 are both gestures macOS answers (pages,
    /// full-screen apps, Mission Control), and the tap key's value
    /// table is unmeasured, so a reading is taken as owned rather
    /// than shared (owner eyeball on #1873).
    static let swipeKeys: [(String, Int, Axis)] = [
        ("TrackpadThreeFingerHorizSwipeGesture", 3, .horizontal),
        ("TrackpadThreeFingerVertSwipeGesture", 3, .vertical),
        ("TrackpadFourFingerHorizSwipeGesture", 4, .horizontal),
        ("TrackpadFourFingerVertSwipeGesture", 4, .vertical),
    ]
    static let tapKey = "TrackpadThreeFingerTapGesture"
    /// Three-finger drag zeroes the three-finger swipe keys while
    /// it drags with those fingers, so it owns both axes.
    static let dragKey = "TrackpadThreeFingerDrag"

    /// The verdict over the keys read; none read is unread, since
    /// a domain System Settings never wrote states no choice.
    static func parse(_ prefs: [String: Int]) -> TrackpadSystemGestures {
        guard !prefs.isEmpty else { return .unread }
        var swipes: [Int: Set<Axis>] = [:]
        for (key, fingers, axis) in swipeKeys
        where (prefs[key] ?? 0) != 0 {
            swipes[fingers, default: []].insert(axis)
        }
        if (prefs[dragKey] ?? 0) != 0 {
            swipes[3, default: []].formUnion([.horizontal, .vertical])
        }
        return TrackpadSystemGestures(
            swipes: swipes,
            lookUpTap: (prefs[tapKey] ?? 0) != 0
        )
    }

    /// The built-in trackpad's domain and the Magic Trackpad's
    /// driver's; a key either one sets counts.
    static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    /// The live read.
    static func readLive() -> TrackpadSystemGestures {
        var prefs: [String: Int] = [:]
        for domain in domains {
            CFPreferencesAppSynchronize(domain as CFString)
            for key in swipeKeys.map(\.0) + [tapKey, dragKey] {
                if let value = CFPreferencesCopyAppValue(
                    key as CFString,
                    domain as CFString
                ) as? Int, value != 0 || prefs[key] == nil {
                    prefs[key] = value
                }
            }
        }
        return parse(prefs)
    }
}
