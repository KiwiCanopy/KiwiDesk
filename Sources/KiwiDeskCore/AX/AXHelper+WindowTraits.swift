import ApplicationServices
import CoreGraphics

/// How one window reads to the shadow rule (#1785).
enum ShellReading: Equatable {
    /// A title-bar button or an AX child: a window.
    case furnished
    /// Neither, and every read answered.
    case shell
    /// A read did not answer; never taken as empty.
    case unread

    /// `button` and `children` are nil where the read failed.
    static func of(button: Bool?, children: Int?) -> ShellReading {
        if button == true { return .furnished }
        if let children, children > 0 { return .furnished }
        guard button == false, children == 0 else { return .unread }
        return .shell
    }
}

/// What the shadow-window rule reads of one AX window (#1785).
struct WindowTraits: Equatable {
    let id: WindowID
    /// Close, minimize, zoom or full-screen button present; nil
    /// when the read did not answer.
    let hasTitlebarButton: Bool?
    /// nil when the read did not answer.
    let childCount: Int?
    let frame: CGRect

    var reading: ShellReading {
        .of(button: hasTitlebarButton, children: childCount)
    }

    /// The buttoned window of its process a shell mirrors (#1785):
    /// the one on its frame, else at its size, else any — a shell
    /// parks at 1×1, and KiwiDesk may have resized one it tiled
    /// (device, 2026-09-30). A shell alone in its app has none.
    static func shadowHost(
        of twin: WindowTraits,
        among siblings: [WindowTraits]
    ) -> WindowID? {
        guard twin.reading == .shell else { return nil }
        let hosts = siblings.filter {
            $0.id != twin.id && $0.hasTitlebarButton == true
        }
        return
            (hosts.first { sameFrame($0.frame, twin.frame) }
            ?? hosts.first { sameSize($0.frame, twin.frame) }
            ?? hosts.first)?.id
    }

    private static let tolerance = TabReconciler.frameTolerance

    private static func sameSize(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }

    private static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && sameSize(a, b)
    }
}

extension AXHelper {
    private static let titlebarButtons = [
        kAXCloseButtonAttribute, kAXMinimizeButtonAttribute,
        kAXZoomButtonAttribute, kAXFullScreenButtonAttribute,
    ]

    /// The shadow rule's reading of one window, in ONE round trip
    /// whatever the window holds — Orion answers a read in
    /// 100–600 ms while busy (device, 2026-09-30). `id` spares
    /// the id's own round trip where the caller holds it; nil
    /// without one.
    static func windowTraits(
        _ element: AXUIElement,
        id known: WindowID?
    ) -> WindowTraits? {
        guard let id = known ?? windowID(of: element) else { return nil }
        let names =
            titlebarButtons + [
                kAXChildrenAttribute, kAXPositionAttribute,
                kAXSizeAttribute,
            ]
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element,
            names as CFArray,
            AXCopyMultipleAttributeOptions(rawValue: 0),
            &values
        )
        guard error == .success,
            let items = values as? [AnyObject],
            items.count == names.count
        else {
            return WindowTraits(
                id: id,
                hasTitlebarButton: nil,
                childCount: nil,
                frame: .zero
            )
        }
        let buttons = items.prefix(titlebarButtons.count).map(carries)
        let children = items[titlebarButtons.count]
        return WindowTraits(
            id: id,
            hasTitlebarButton: buttons.contains(true)
                ? true : buttons.contains(nil) ? nil : false,
            childCount: (children as? [AnyObject])?.count
                ?? (carries(children) == false ? 0 : nil),
            frame: frame(
                position: items[titlebarButtons.count + 1],
                size: items[titlebarButtons.count + 2]
            )
        )
    }

    /// Whether a batched read's item carries a value: false where
    /// the element answered it has none, nil where the read
    /// failed.
    private static func carries(_ item: AnyObject) -> Bool? {
        guard CFGetTypeID(item) == AXValueGetTypeID() else {
            return CFGetTypeID(item) != CFNullGetTypeID()
        }
        // swift-format-ignore: NeverForceUnwrap
        let value = item as! AXValue
        guard AXValueGetType(value) == .axError else { return true }
        var error = AXError.success
        AXValueGetValue(value, .axError, &error)
        return error == .noValue || error == .attributeUnsupported
            ? false : nil
    }

    private static func frame(
        position: AnyObject,
        size: AnyObject
    ) -> CGRect {
        guard CFGetTypeID(position) == AXValueGetTypeID(),
            CFGetTypeID(size) == AXValueGetTypeID()
        else { return .zero }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        // swift-format-ignore: NeverForceUnwrap
        guard
            AXValueGetValue(position as! AXValue, .cgPoint, &origin),
            AXValueGetValue(size as! AXValue, .cgSize, &extent)
        else { return .zero }
        return CGRect(origin: origin, size: extent)
    }
}
