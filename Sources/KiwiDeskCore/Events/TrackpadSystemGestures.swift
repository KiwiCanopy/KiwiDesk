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
        case .swipe(let direction):
            let axis: Axis =
                direction == .left || direction == .right
                ? .horizontal : .vertical
            return swipes[event.fingers]?.contains(axis) ?? false
        }
    }

    /// The preference keys and the values that mean "on": 2 for
    /// a swipe (1 is three-finger drag's), and for the tap 2,
    /// Look up rather than tap-to-click's own.
    static let swipeKeys: [(String, Int, Axis)] = [
        ("TrackpadThreeFingerHorizSwipeGesture", 3, .horizontal),
        ("TrackpadThreeFingerVertSwipeGesture", 3, .vertical),
        ("TrackpadFourFingerHorizSwipeGesture", 4, .horizontal),
        ("TrackpadFourFingerVertSwipeGesture", 4, .vertical),
    ]
    static let tapKey = "TrackpadThreeFingerTapGesture"

    /// The verdict over the keys read; none read is unread, since
    /// a domain System Settings never wrote states no choice.
    static func parse(_ prefs: [String: Int]) -> TrackpadSystemGestures {
        guard !prefs.isEmpty else { return .unread }
        var swipes: [Int: Set<Axis>] = [:]
        for (key, fingers, axis) in swipeKeys
        where prefs[key] == 2 {
            swipes[fingers, default: []].insert(axis)
        }
        return TrackpadSystemGestures(
            swipes: swipes,
            lookUpTap: prefs[tapKey] == 2
        )
    }

    /// The built-in trackpad's domain; a Magic Trackpad writes the
    /// same keys to the Bluetooth driver's, which System Settings
    /// keeps in step.
    static let domain = "com.apple.AppleMultitouchTrackpad"

    /// The live read.
    static func readLive() -> TrackpadSystemGestures {
        var prefs: [String: Int] = [:]
        for key in swipeKeys.map(\.0) + [tapKey] {
            if let value = CFPreferencesCopyAppValue(
                key as CFString,
                domain as CFString
            ) as? Int {
                prefs[key] = value
            }
        }
        return parse(prefs)
    }
}
