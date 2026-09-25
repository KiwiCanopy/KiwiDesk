import AppKit

/// What tells KiwiDesk to re-measure the screens: AppKit's
/// screen-parameter notification, and the menu-bar auto-hide pref
/// itself — macOS skips that notification on some auto-hide
/// toggles, leaving `NSScreen.visibleFrame` stale (#1386). Also
/// holds the drawn-menu-bar read the re-measure takes.
@MainActor
final class DisplayWatch {
    /// The WindowServer's drawn menu bars, CG coordinates. Empty
    /// until `KiwiCore` wires `liveMenuBars`, so a bare loop in a
    /// test never files the host's bars.
    var readDrawnMenuBars: () -> [CGRect] = { [] }
    /// Fired when the auto-hide pref flips; the core re-measures
    /// once the bar has settled (`scheduleMenuBarRemeasure`).
    var onMenuBarPrefChange: () -> Void = {}

    private var screenToken: NSObjectProtocol?
    private var prefObserver: MenuBarPrefObserver?

    /// Starts both observations; `onScreensChanged` runs on every
    /// screen-parameter notification.
    func start(onScreensChanged: @escaping @MainActor () -> Void) {
        screenToken = NotificationCenter.default.addObserver(
            forName:
                NSApplication
                .didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onScreensChanged() }
        }
        prefObserver = MenuBarPrefObserver { [weak self] in
            self?.onMenuBarPrefChange()
        }
    }

    /// Every menu-bar-level window the WindowServer itself lists
    /// on screen, CG coordinates — matched by owner and level,
    /// never by window name, which reads nil without Screen
    /// Recording.
    static func liveMenuBars() -> [CGRect] {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        let list =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard
                info[kCGWindowOwnerName as String] as? String
                    == "Window Server",
                info[kCGWindowLayer as String] as? Int == level,
                let bounds =
                    info[kCGWindowBounds as String] as? NSDictionary
            else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
    }

    func stop() {
        if let screenToken {
            NotificationCenter.default.removeObserver(screenToken)
        }
        screenToken = nil
        prefObserver?.invalidate()
        prefObserver = nil
    }
}

/// KVO on the global `_HIHideMenuBar` pref, which fired on every
/// toggle measured (#1386), delivered on the main actor.
private final class MenuBarPrefObserver: NSObject {
    static let key = "_HIHideMenuBar"

    private let onChange: @MainActor @Sendable () -> Void

    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        UserDefaults.standard.addObserver(
            self,
            forKeyPath: Self.key,
            options: [],
            context: nil
        )
    }

    func invalidate() {
        UserDefaults.standard.removeObserver(
            self,
            forKeyPath: Self.key
        )
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        let onChange = self.onChange
        DispatchQueue.main.async {
            MainActor.assumeIsolated { onChange() }
        }
    }
}
