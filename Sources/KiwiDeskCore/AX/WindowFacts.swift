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
    /// Whether the window offers Cancel in place of close — its
    /// close button disabled and a window-level `AXCancelButton`:
    /// a progress window such as Archive Utility's (#2653). Asked
    /// like the zoom button, and only where it answers no.
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
        WindowFacts(
            role: role ?? AXHelper.role(of: element),
            subrole: AXHelper.subrole(of: element),
            layer: layer,
            zoomable: {
                AXHelper.attribute(
                    element,
                    kAXZoomButtonAttribute,
                    as: AXUIElement.self
                ).flatMap {
                    AXHelper.attribute(
                        $0,
                        kAXEnabledAttribute,
                        as: Bool.self
                    )
                }
            },
            cancelsInsteadOfClosing: {
                cancelsInsteadOfClosing(element)
            }
        ) { AXHelper.title(of: element) }
    }

    /// The close button reads disabled and the window carries a
    /// Cancel button; the second read only where the first holds.
    private static func cancelsInsteadOfClosing(
        _ element: AXUIElement
    ) -> Bool {
        let close = AXHelper.attribute(
            element,
            kAXCloseButtonAttribute,
            as: AXUIElement.self
        )
        guard
            let close,
            AXHelper.attribute(
                close,
                kAXEnabledAttribute,
                as: Bool.self
            ) == false
        else { return false }
        return AXHelper.attribute(
            element,
            kAXCancelButtonAttribute,
            as: AXUIElement.self
        ) != nil
    }
}
