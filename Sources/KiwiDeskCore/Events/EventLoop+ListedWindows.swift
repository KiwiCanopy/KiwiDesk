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
        let role = AXHelper.role(of: element)
        let subrole = AXHelper.subrole(of: element)
        var reading: TrackedReading?
        if let id, !minimized, tracked.contains(id) {
            reading = TrackedReading(
                fullscreen: fullscreen(element),
                frame: AXHelper.frame(of: element),
                autoReason: FloatDetection.autoFloatReason(
                    role: role,
                    subrole: subrole,
                    layer: layers[id],
                    bundleID: bundleID,
                    rules: rules
                ) { AXHelper.title(of: element) },
                traits: many ? traits(element, id) : nil
            )
        }
        return ListedWindow(
            id: id,
            minimized: minimized,
            role: role,
            subrole: subrole,
            tracked: reading
        )
    }
}
