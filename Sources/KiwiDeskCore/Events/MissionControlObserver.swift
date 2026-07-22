import AppKit
import ApplicationServices

/// Watches macOS Mission Control / Exposé so KiwiDesk can hide its
/// overlays while the overview is up. The focus ring is a sticky
/// WindowServer window (like JankyBorders') and the App Bar, Space
/// Bar and sticky chips are `.stationary` panels — all of which
/// otherwise float over the overview instead of vanishing with the
/// windows they annotate.
///
/// Detection follows yabai's proven pattern: an `AXObserver` on the
/// Dock process, which posts private `AXExpose*` notifications on
/// every enter edge (all-windows / app-windows / show-desktop) and a
/// single exit edge. There is no public API for this, and the
/// SkyLight enter event (1204) has no SkyLight exit counterpart, so
/// the Dock AX notifications are the only signal carrying both edges.
///
/// If the Dock element is unreachable or the private names stop
/// firing, the observer never reports active and the overlays simply
/// stay visible in Mission Control, exactly as before — a graceful
/// AX-only degrade, no SIP, no crash.
@MainActor
final class MissionControlObserver {
    /// Private Dock notifications marking a Mission Control / Exposé
    /// entry — the three overview modes.
    private static let enterNames = [
        "AXExposeShowAllWindows",
        "AXExposeShowFrontWindows",
        "AXExposeShowDesktop",
    ]
    /// The lone exit edge. The SkyLight 1204 enter event carries no
    /// matching exit, so the overview's close is learned only here.
    private static let exitName = "AXExposeExit"

    /// Unsafe only so Swift 6's nonisolated `deinit` can pull the
    /// run-loop source; every operational access stays MainActor
    /// (mirrors `SkyLightBorderOverlay`'s CF handle).
    nonisolated(unsafe) private let observer: AXObserver
    private let dockElement: AXUIElement
    private let onChange: (Bool) -> Void

    /// Nil when the Dock process or AX observer can't be reached, or
    /// when not a single private notification registers — the caller
    /// then runs without Mission Control awareness.
    init?(onChange: @escaping (Bool) -> Void) {
        guard
            let dockPID =
                NSRunningApplication
                .runningApplications(
                    withBundleIdentifier: "com.apple.dock"
                )
                .first?.processIdentifier
        else { return nil }

        var created: AXObserver?
        guard
            AXObserverCreate(
                dockPID,
                missionControlObserverCallback,
                &created
            ) == .success,
            let observer = created
        else { return nil }

        self.observer = observer
        dockElement = AXUIElementCreateApplication(dockPID)
        self.onChange = onChange

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        func register(_ name: String) -> Bool {
            AXObserverAddNotification(
                observer,
                dockElement,
                name as CFString,
                refcon
            ) == .success
        }
        let anyEnter = Self.enterNames.map(register).contains(true)
        let exitRegistered = register(Self.exitName)
        // Both edges are required. Registering only enters would hide
        // the overlays and never restore them — strictly worse than the
        // no-observer degrade — so a missing exit edge retires the whole
        // observer and overlays keep their prior (visible) behavior.
        guard anyEnter, exitRegistered else { return nil }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }

    deinit {
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }

    fileprivate func handle(_ notification: String) {
        onChange(notification != Self.exitName)
    }
}

/// C trampoline. The observer's run-loop source is on the main run
/// loop, so this always fires on the main thread; `assumeIsolated`
/// hops back onto the actor without a dispatch.
private func missionControlObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let this = Unmanaged<MissionControlObserver>
        .fromOpaque(refcon)
        .takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { this.handle(name) }
}
