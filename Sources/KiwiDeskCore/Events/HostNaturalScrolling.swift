import Foundation

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
