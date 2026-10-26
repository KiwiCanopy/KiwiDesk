import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// One listed window as the off-main read found it (#1933), so
/// the reconcile applying the list on the main actor asks the app
/// nothing per window. Every value is up to one read old.
struct ListedWindow {
    let id: WindowID?
    let minimized: Bool
    let role: String
    let subrole: String
    /// The window's title-bar button where the #2072 escape asks
    /// it (`needsTitlebarButton`); false elsewhere and where the
    /// read did not answer.
    var titlebarButton = false
    /// Read only for a window tracked when the read began.
    let tracked: TrackedReading?
    /// Read only for a window untracked when the read began and
    /// not minimized: what `track` adopts it from.
    var arrival: ArrivalReading?

    var isStandardWindow: Bool {
        role == kAXWindowRole && subrole == kAXStandardWindowSubrole
    }
}

/// What `recheckFloat`, the frame refresh and `retireShadows`
/// would otherwise read of a tracked window on the main actor.
struct TrackedReading {
    let fullscreen: Bool
    let subrole: String
    let frame: CGRect
    /// Detection's verdict, before the force-float override the
    /// main actor applies (`autoFloatVerdict`).
    let autoReason: AutoFloatReason?
    /// nil where the list holds one window, which spares the read.
    let traits: WindowTraits?
}

/// What `track` would otherwise read on the main actor of a
/// window untracked when the list read began, so a Desktop
/// switch's arrivals are adopted without asking their apps again.
/// Up to one read old, like `TrackedReading`: a title changed or a
/// float rule reloaded during the read lands at the window's next
/// title change or recheck, and a window closed or minimized during
/// it is not adopted from it (`OffMainReconcile.departures`).
struct ArrivalReading {
    let id: WindowID
    /// The layer detection judged on; `track` reads the window
    /// live where the server now reports another.
    let layer: Int?
    let role: String
    let subrole: String
    let title: String
    let frame: CGRect
    let fullscreen: Bool
    let nativeTabs: Bool
    /// Detection's verdict, before the force-float override.
    let autoReason: AutoFloatReason?
    /// The shadow rule's reading; nil where the read did not
    /// answer, which `shadowVerdict` takes as the live read's nil.
    let traits: WindowTraits?

    /// `AXHelper.snapshot` over what was read.
    func window(pid: pid_t, app: AppRef) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid,
            appName: app.name,
            appBundleID: app.bundleID,
            title: title,
            frame: frame
        )
    }
}

/// An app's window list and what was read of each window, handed
/// across threads: an `AXUIElement` is an immutable CF reference.
struct WindowListReading: @unchecked Sendable {
    let elements: [AXUIElement]
    /// Parallel to `elements`.
    let windows: [ListedWindow]
    /// The listed windows' WindowServer layers.
    let layers: [WindowID: Int]
    /// LaunchServices' policy and hidden state, read beside the
    /// list so the main actor asks neither (#1936); nil policy
    /// without a record.
    let policy: NSApplication.ActivationPolicy?
    let hidden: Bool
    /// False where a hidden app's list was skipped (#2027): the
    /// empty list then speaks for no window.
    var listRead = true
    /// When the read RAN, off the main actor: a queued read runs
    /// after one asked later, so the ask's time cannot order them.
    var readStarted: ContinuousClock.Instant?
}

/// Reads a list's windows OFF the main actor (#1933). The seams
/// are the loop's own, captured at request time, and each must
/// read no `EventLoop` state: one that needs it is resolved on the
/// main actor at request time, as `tracked` is.
struct ListedWindowReader: @unchecked Sendable {
    let resolve: (AXUIElement) -> WindowID?
    let fullscreen: (AXUIElement) -> Bool
    let traits: (AXUIElement, WindowID?) -> WindowTraits?
    let bundleID: String?
    let rules: FloatRules
    let facts: (AXUIElement, Int?) -> WindowFacts
    let tracked: Set<WindowID>
    /// The app's overlay class, resolved at request time.
    let isAccessory: Bool
    /// What spares an untracked window the arrival read where
    /// `track` might refuse it, resolved at request time: the
    /// ignore rules, KiwiDesk's own process (its gate asks AppKit)
    /// and the app's known shadows. A prefilter: a window it lets
    /// through costs reads, one it holds back is read live.
    let ignoreRules: IgnoreRules
    let ownProcess: Bool
    let shadowed: Set<WindowID>

    /// Each element's window, and the layers read for them.
    func read(
        _ elements: [AXUIElement],
        layer: (WindowID) -> Int?
    ) -> ([ListedWindow], [WindowID: Int]) {
        var layers: [WindowID: Int] = [:]
        let windows = elements.map { element in
            let id = resolve(element)
            let listed = id.flatMap(layer)
            if let id, let listed { layers[id] = listed }
            return read(
                element,
                id: id,
                listedLayer: listed,
                many: elements.count > 1
            )
        }
        return (windows, layers)
    }

    private func read(
        _ element: AXUIElement,
        id: WindowID?,
        listedLayer: Int?,
        many: Bool
    ) -> ListedWindow {
        let minimized = AXHelper.isMinimized(element)
        let facts = facts(element, listedLayer)
        let layer = listedLayer ?? 0
        let asksButton = FloatDetection.needsTitlebarButton(
            layer: layer,
            isAccessory: isAccessory,
            bundleID: bundleID,
            subrole: facts.subrole
        )
        let isTracked = id.map { tracked.contains($0) }
        let button = asksButton ? traits(element, id) : nil
        let arrives =
            isTracked == false && !minimized && !ownProcess
            && facts.role == kAXWindowRole
            && id.map(shadowed.contains) == false
            && !FloatDetection.shouldIgnore(
                bundleID: bundleID,
                layer: layer,
                isAccessory: isAccessory,
                rules: ignoreRules,
                titlebarButton: button?.hasTitlebarButton == true
            )
        // One traits read serves the shadow rule and the escape.
        let traitsRead =
            button
            ?? (!asksButton && (isTracked == true && many || arrives)
                ? traits(element, id) : nil)
        let detect = {
            FloatDetection.autoFloatReason(
                facts,
                bundleID: bundleID,
                rules: rules
            )
        }
        var reading: TrackedReading?
        if isTracked == true, !minimized {
            reading = TrackedReading(
                fullscreen: fullscreen(element),
                subrole: facts.subrole,
                frame: AXHelper.frame(of: element),
                autoReason: detect(),
                traits: many ? traitsRead : nil
            )
        }
        return ListedWindow(
            id: id,
            minimized: minimized,
            role: facts.role,
            subrole: facts.subrole,
            titlebarButton: asksButton
                && traitsRead?.hasTitlebarButton == true,
            tracked: reading,
            arrival: arrives
                ? id.map {
                    arrival(
                        $0,
                        element,
                        facts,
                        listedLayer,
                        traitsRead,
                        detect
                    )
                }
                : nil
        )
    }

    /// Per arrival, what `track` asked on the main actor — the
    /// title, frame, fullscreen state, batched traits, children
    /// and each child's role, and detection's title and button
    /// reads where it asks them: about 6 + children AX messages
    /// moved off the main actor per arriving window, one more for
    /// a window carrying a Cancel button (#2653).
    private func arrival(
        _ id: WindowID,
        _ element: AXUIElement,
        _ facts: WindowFacts,
        _ layer: Int?,
        _ traits: WindowTraits?,
        _ detect: () -> AutoFloatReason?
    ) -> ArrivalReading {
        ArrivalReading(
            id: id,
            layer: layer,
            role: facts.role,
            subrole: facts.subrole,
            title: facts.title(),
            frame: AXHelper.frame(of: element),
            fullscreen: fullscreen(element),
            nativeTabs: AXHelper.hasNativeTabs(element),
            autoReason: detect(),
            traits: traits
        )
    }
}

extension EventLoop {
    /// The reader for `pid`'s next off-main list read.
    func listedWindowReader(
        pid: pid_t,
        bundleID: String?,
        tracked: Set<WindowID>
    ) -> ListedWindowReader {
        ListedWindowReader(
            resolve: resolveWindowID,
            fullscreen: readFullscreen,
            traits: shadows.traits,
            bundleID: bundleID,
            rules: floatRules,
            facts: offMain.readFacts,
            tracked: tracked,
            isAccessory: classifiesAsOverlay(pid: pid),
            ignoreRules: ignoreRules,
            ownProcess: Self.isOwnProcess(pid),
            shadowed: Set(shadows.hosts[pid]?.keys ?? [:].keys)
        )
    }

    /// The blocking list read behind an off-main reconcile, built
    /// on the main actor and run off it: a hidden app's list is
    /// skipped unless `listsWhenHidden` (#2027).
    func windowListRead(
        pid: pid_t,
        app: AppRef,
        tracked: Set<WindowID>,
        listsWhenHidden: Bool
    ) -> @Sendable () -> WindowListReading {
        let reader = listedWindowReader(
            pid: pid,
            bundleID: app.bundleID,
            tracked: tracked
        )
        nonisolated(unsafe) let read = axWindows
        nonisolated(unsafe) let readPolicy = activationPolicy
        nonisolated(unsafe) let readHidden = appIsHidden
        nonisolated(unsafe) let readLayers = offMain.readLayers
        return {
            let started = ContinuousClock.now
            let hidden = readHidden(pid)
            guard !hidden || listsWhenHidden else {
                return WindowListReading(
                    elements: [],
                    windows: [],
                    layers: [:],
                    policy: readPolicy(pid),
                    hidden: true,
                    listRead: false,
                    readStarted: started
                )
            }
            let elements = read(pid)
            let (windows, layers) = reader.read(
                elements,
                layer: readLayers(pid)
            )
            return WindowListReading(
                elements: elements,
                windows: windows,
                layers: layers,
                policy: readPolicy(pid),
                hidden: hidden,
                readStarted: started
            )
        }
    }
}
