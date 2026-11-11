import Foundation

/// One input's Natural scrolling (#3200 ruling ▸ "System" as a
/// third value): follow macOS's own choice live, or pin it. The
/// wire takes exactly `"system"`, `true` or `false`, so a stored
/// bool keeps its meaning and no migration is owed.
public enum NaturalScrolling: Hashable, Sendable, CaseIterable {
    case system, on, off

    /// What a scroll on this input does, given macOS's choice.
    public func isNatural(host: Bool) -> Bool {
        switch self {
        case .system: host
        case .on: true
        case .off: false
        }
    }

    /// A pinned value for `natural`.
    public static func pinned(_ natural: Bool) -> NaturalScrolling {
        natural ? .on : .off
    }
}

extension NaturalScrolling: Codable {
    static let systemSpelling = "system"

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let flag = try? c.decode(Bool.self) {
            self = .pinned(flag)
            return
        }
        guard try c.decode(String.self) == Self.systemSpelling else {
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "expected \"system\", true or false"
            )
        }
        self = .system
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .system: try c.encode(Self.systemSpelling)
        case .on: try c.encode(true)
        case .off: try c.encode(false)
        }
    }
}

/// macOS's own Natural scrolling, cached (#3200): one global
/// default for every input, read at wiring and again when macOS
/// says it changed, never per scroll event.
struct HostNaturalScrolling {
    /// The live read; nil where the key is unset, which macOS
    /// reads as on.
    var read: @MainActor () -> Bool?
    /// Calls back on the main actor whenever the setting changes.
    var watch: @MainActor (@escaping @MainActor () -> Void) -> Void

    static let key = "com.apple.swipescrolldirection"

    static let live = HostNaturalScrolling(
        read: {
            CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
            return CFPreferencesCopyAppValue(
                key as CFString,
                kCFPreferencesAnyApplication
            ) as? Bool
        },
        watch: { changed in
            DistributedNotificationCenter.default().addObserver(
                forName: changeNotice,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated { changed() }
            }
        }
    )

    /// What a test core answers: unset, and never a change.
    static let unset = HostNaturalScrolling(
        read: { nil },
        watch: { _ in }
    )

    /// Posted when the setting flips, the default already written
    /// (measured on device 2026-11-11, macOS 27.2; KVO on the
    /// default and `UserDefaults.didChangeNotification` stayed
    /// silent).
    static let changeNotice = Notification.Name(
        "SwipeScrollDirectionDidChangeNotification"
    )
}
