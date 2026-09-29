import ApplicationServices
import CoreGraphics

/// What the shadow-window rule reads of one AX window (#1785).
struct WindowTraits: Equatable {
    let id: WindowID
    /// Close, minimize, zoom or full-screen button present.
    let hasTitlebarButton: Bool
    let childCount: Int
    let frame: CGRect

    /// An empty, button-less window beside a real window of the
    /// same process — Orion's "Orion Preview" twin, which tracked
    /// as a tile fought its host for the slot and the focus. The
    /// buttoned sibling is what separates it from a frameless real
    /// window alone in its app (a terminal, an Electron app). Not
    /// the frame: a twin tracked before its host appeared is tiled
    /// away from it, and would never match again (device,
    /// 2026-09-29). Returns the host, the same-frame one first.
    static func shadowHost(
        of twin: WindowTraits,
        among siblings: [WindowTraits]
    ) -> WindowID? {
        guard !twin.hasTitlebarButton, twin.childCount == 0
        else { return nil }
        let hosts = siblings.filter {
            $0.id != twin.id && $0.hasTitlebarButton
        }
        return
            (hosts.first { sameFrame($0.frame, twin.frame) }
            ?? hosts.first)?.id
    }

    private static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
            && abs(a.width - b.width) <= 2
            && abs(a.height - b.height) <= 2
    }
}

extension AXHelper {
    private static let titlebarButtons = [
        kAXCloseButtonAttribute, kAXMinimizeButtonAttribute,
        kAXZoomButtonAttribute, kAXFullScreenButtonAttribute,
    ]

    /// Whether the window carries any title-bar button. Stops at
    /// the first one found: a real window pays one read.
    static func hasTitlebarButton(_ element: AXUIElement) -> Bool {
        titlebarButtons.contains { name in
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(
                element,
                name as CFString,
                &value
            ) == .success && value != nil
        }
    }

    /// The shadow rule's reading of one window; nil without an id.
    static func windowTraits(_ element: AXUIElement) -> WindowTraits? {
        guard let id = windowID(of: element) else { return nil }
        var count: CFIndex = 0
        let read = AXUIElementGetAttributeValueCount(
            element,
            kAXChildrenAttribute as CFString,
            &count
        )
        return WindowTraits(
            id: id,
            hasTitlebarButton: hasTitlebarButton(element),
            childCount: read == .success ? count : -1,
            frame: frame(of: element)
        )
    }
}
