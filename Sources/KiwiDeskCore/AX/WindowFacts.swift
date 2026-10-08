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

    public init(
        role: String,
        subrole: String,
        layer: Int?,
        title: @escaping () -> String
    ) {
        self.role = role
        self.subrole = subrole
        self.layer = layer
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
            layer: layer
        ) { AXHelper.title(of: element) }
    }
}
