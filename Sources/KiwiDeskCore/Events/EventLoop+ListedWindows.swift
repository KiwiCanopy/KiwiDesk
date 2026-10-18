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
    /// Read only for a window tracked when the read began; the
    /// reconcile reads any other the way it always has.
    let tracked: TrackedReading?

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

/// An app's window list and what was read of each window, handed
/// across threads: an `AXUIElement` is an immutable CF reference.
struct WindowListReading: @unchecked Sendable {
    let elements: [AXUIElement]
    /// Parallel to `elements`.
    let windows: [ListedWindow]
    /// The app's WindowServer layers, one snapshot for the pass.
    let layers: [WindowID: Int]
    /// LaunchServices' policy and hidden state, read beside the
    /// list so the main actor asks neither (#1936); nil policy
    /// without a record.
    let policy: NSApplication.ActivationPolicy?
    let hidden: Bool
    /// False where a hidden app's list was skipped (#2027): the
    /// empty list then speaks for no window.
    var listRead = true
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
    let tracked: Set<WindowID>
    /// The app's overlay class, resolved at request time.
    let isAccessory: Bool

    func read(
        _ elements: [AXUIElement],
        layers: [WindowID: Int]
    ) -> [ListedWindow] {
        elements.map { read($0, layers: layers, many: elements.count > 1) }
    }

    private func read(
        _ element: AXUIElement,
        layers: [WindowID: Int],
        many: Bool
    ) -> ListedWindow {
        let id = resolve(element)
        let minimized = AXHelper.isMinimized(element)
        let facts = WindowFacts.read(
            element,
            layer: id.flatMap { layers[$0] }
        )
        let layer = id.flatMap { layers[$0] } ?? 0
        let asksButton = FloatDetection.needsTitlebarButton(
            layer: layer,
            isAccessory: isAccessory,
            bundleID: bundleID
        )
        // One traits read serves the shadow rule and the escape.
        let traitsRead =
            id.map { tracked.contains($0) } == true && many || asksButton
            ? traits(element, id) : nil
        var reading: TrackedReading?
        if let id, !minimized, tracked.contains(id) {
            reading = TrackedReading(
                fullscreen: fullscreen(element),
                subrole: facts.subrole,
                frame: AXHelper.frame(of: element),
                autoReason: FloatDetection.autoFloatReason(
                    facts,
                    bundleID: bundleID,
                    rules: rules
                ),
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
            tracked: reading
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
            tracked: tracked,
            isAccessory: classifiesAsOverlay(pid: pid)
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
        return {
            let hidden = readHidden(pid)
            guard !hidden || listsWhenHidden else {
                return WindowListReading(
                    elements: [],
                    windows: [],
                    layers: [:],
                    policy: readPolicy(pid),
                    hidden: true,
                    listRead: false
                )
            }
            let elements = read(pid)
            let layers = FloatDetection.windowLayers(pid: pid)
            return WindowListReading(
                elements: elements,
                windows: reader.read(elements, layers: layers),
                layers: layers,
                policy: readPolicy(pid),
                hidden: hidden
            )
        }
    }
}
