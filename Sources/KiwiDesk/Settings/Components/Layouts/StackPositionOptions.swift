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

    /// Titles come from the diff readout's one switch, so the
    /// chooser and its readout name a position alike.
    @MainActor
    static var all: [(StackParams.StackPosition, String)] {
        order.map { ($0, SettingsValueReadout.layoutPosition($0)) }
    }
}
