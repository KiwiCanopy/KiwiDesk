import ApplicationServices
import CoreGraphics

/// What the shadow-window rule reads of one AX window (#1785).
struct WindowTraits: Equatable {
    let id: WindowID
    /// Close, minimize, zoom or full-screen button present.
    let hasTitlebarButton: Bool
    let childCount: Int
    let frame: CGRect

    /// An empty, button-less window on the frame — or at the
    /// size — of a buttoned window of its process: the host it
    /// mirrors (#1785). A frameless real window alone in its app
    /// has no such sibling.
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
            ?? hosts.first { sameSize($0.frame, twin.frame) }
            ?? hosts.first)?.id
    }

    private static func sameSize(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }

    private static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
            && sameSize(a, b)
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

    /// The window's AX child count; -1 when the read fails, which
    /// the shadow rule never reads as empty.
    static func childCount(_ element: AXUIElement) -> Int {
        var count: CFIndex = 0
        return AXUIElementGetAttributeValueCount(
            element,
            kAXChildrenAttribute as CFString,
            &count
        ) == .success ? count : -1
    }

    /// The shadow rule's reading of one window; nil without an id.
    static func windowTraits(_ element: AXUIElement) -> WindowTraits? {
        guard let id = windowID(of: element) else { return nil }
        return WindowTraits(
            id: id,
            hasTitlebarButton: hasTitlebarButton(element),
            childCount: childCount(element),
            frame: frame(of: element)
        )
    }
}
