import ApplicationServices

/// What float detection reads of one window, as plain values
/// (#1883). Every live producer builds it through `read`, and a
/// recorded dump builds it by hand, so a fixture runs the body a
/// live window does.
public struct WindowFacts {
    public let role: String
    public let subrole: String
    /// The WindowServer layer; nil where the server lists none.
    public let layer: Int?
    /// Asked only where structure tiles: live, a round trip.
    public let title: () -> String
    /// Whether the zoom button is enabled (#2070): false for a
    /// window that cannot be resized, nil where it has no zoom
    /// button or the read failed. Asked like the title.
    public let zoomable: () -> Bool?
    /// Whether the window offers Cancel in place of close (#2653):
    /// a progress window such as Archive Utility's. Asked only
    /// where the zoom button does not already answer fixed-size.
    public let cancelsInsteadOfClosing: () -> Bool

    public init(
        role: String,
        subrole: String,
        layer: Int?,
        zoomable: @escaping () -> Bool? = { nil },
        cancelsInsteadOfClosing: @escaping () -> Bool = { false },
        title: @escaping () -> String
    ) {
        self.role = role
        self.subrole = subrole
        self.layer = layer
        self.zoomable = zoomable
        self.cancelsInsteadOfClosing = cancelsInsteadOfClosing
        self.title = title
    }

    /// The live reading, the one door every AX producer takes;
    /// `role` is handed in where the caller already gated on it.
    static func read(
        _ element: AXUIElement,
        role: String? = nil,
        layer: Int?
    ) -> WindowFacts {
        let buttons = WindowButtons(element)
        return WindowFacts(
            role: role ?? AXHelper.role(of: element),
            subrole: AXHelper.subrole(of: element),
            layer: layer,
            zoomable: { buttons.zoom.flatMap(WindowButtons.enabled) },
            cancelsInsteadOfClosing: {
                WindowFacts.cancelsInsteadOfClosing(
                    hasCancel: buttons.cancel != nil
                ) { buttons.close.flatMap(WindowButtons.enabled) }
            }
        ) { AXHelper.title(of: element) }
    }

    /// Cancel offered in place of close (#2653): a close button
    /// that reads disabled beside a window-level Cancel button.
    /// The one predicate the live read and the dump corpus ask;
    /// `closeEnabled` is asked only where a Cancel button is.
    static func cancelsInsteadOfClosing(
        hasCancel: Bool,
        closeEnabled: () -> Bool?
    ) -> Bool {
        hasCancel && closeEnabled() == false
    }
}

/// The zoom, close and Cancel buttons of one window: ONE batched
/// AX round trip on first ask, kept for the reading (#2653). A
/// window carrying a Cancel button pays one more message, its
/// close button's `AXEnabled`.
final class WindowButtons {
    private let element: AXUIElement
    private var fetched: [AXUIElement?]?

    init(_ element: AXUIElement) {
        self.element = element
    }

    var zoom: AXUIElement? { buttons[0] }
    var close: AXUIElement? { buttons[1] }
    var cancel: AXUIElement? { buttons[2] }

    private var buttons: [AXUIElement?] {
        if let fetched { return fetched }
        let read = Self.fetch(element)
        fetched = read
        return read
    }

    private static func fetch(_ element: AXUIElement) -> [AXUIElement?] {
        let names = [
            kAXZoomButtonAttribute, kAXCloseButtonAttribute,
            kAXCancelButtonAttribute,
        ]
        var values: CFArray?
        let error = WorkMeter.shared.ax {
            AXUIElementCopyMultipleAttributeValues(
                element,
                names as CFArray,
                AXCopyMultipleAttributeOptions(rawValue: 0),
                &values
            )
        }
        guard error == .success,
            let items = values as? [AnyObject],
            items.count == names.count
        else { return [nil, nil, nil] }
        return items.map { item in
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else {
                return nil
            }
            // swift-format-ignore: NeverForceUnwrap
            return (item as! AXUIElement)
        }
    }

    /// A button's `AXEnabled`; nil where the read failed.
    static func enabled(_ button: AXUIElement) -> Bool? {
        AXHelper.attribute(button, kAXEnabledAttribute, as: Bool.self)
    }
}
