import KiwiDeskCore

/// The Stack position choices, as the Layout Defaults row and the
/// per-Space override row both list them (#222).
///
/// COMPUTED, so a locale switch re-reads the titles (#1311).
enum StackPositionOptions {
    /// Presented order, matching every edge chooser's
    /// (`AppBarOptions.edgeOrder`, #2766) — not the enum's case
    /// order, which stays as stored.
    static let order: [StackParams.StackPosition] = [
        .left, .top, .bottom, .right,
    ]

    @MainActor
    static var all: [(StackParams.StackPosition, String)] {
        order.map { ($0, title($0)) }
    }

    @MainActor
    private static func title(
        _ position: StackParams.StackPosition
    ) -> String {
        switch position {
        case .top: L("layout_params.position.top", "Top")
        case .right: L("layout_params.position.right", "Right")
        case .bottom: L("layout_params.position.bottom", "Bottom")
        case .left: L("layout_params.position.left", "Left")
        }
    }
}
