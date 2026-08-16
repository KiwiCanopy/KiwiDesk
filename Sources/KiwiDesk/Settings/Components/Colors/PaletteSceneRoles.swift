import KiwiDeskCore

/// How much of a palette one drawing of it shows (#793).
///
/// The shelf tile and the detail panel are the same renderer at
/// two scales, on the `SchematicScale` precedent (#753): a
/// thumbnail answers "which of these do I want?", and the panel
/// answers the question a thumbnail cannot — do these colours
/// work *together*. Two scales rather than a `height` threshold,
/// because what changes is which roles are drawn, and a number
/// cannot say that.
enum PaletteSceneScale {
    /// The palette shelf's 72 pt tile: composition at a glance.
    case tile
    /// The detail panel: every role a still frame can honestly
    /// draw, so the whole set can be judged at once.
    case panel
}

/// Which colour roles each scale draws — and, for the panel, the
/// argued census of which it does NOT.
///
/// Data rather than a claim in a comment, because the question a
/// reviewer actually has ("is my new colour in the picture?") is
/// unanswerable by reading a SwiftUI body. `PaletteSceneRoleTests`
/// holds the totality: **every path in `ColorPaletteKeys.all` is
/// either drawn at `.panel` or named in `withheld` with a
/// reason**, so a colour joining the palette surface cannot
/// quietly miss the one page whose subject is seeing them
/// together.
enum PaletteSceneRoles {
    /// The seven the shelf tile draws — unchanged by #793. A tile
    /// is 72 pt; adding roles there buys smaller marks, not more
    /// information.
    static let tile: Set<String> = [
        "app_bar.fill_color",
        "app_bar.item_color",
        "app_bar.active_item_color",
        "app_bar.highlight_color",
        "border.focused_color",
        "drag.ghost.fill_color",
        "drag.ghost.border_color",
    ]

    /// The twenty-one the panel draws. Each earns its place by
    /// naming a comparison the user is actually making — the
    /// three-step accent ladder on each bar, focused against
    /// unfocused, the state marks against the accent, and the
    /// drag ghost against its drop zone.
    static let panel: Set<String> = [
        // Space Bar: plate, the accent ladder, the badge pair.
        "space_bar.fill_color",
        "space_bar.item_color",
        "space_bar.active_item_color",
        "space_bar.focused_item_color",
        "space_bar.highlight_color",
        "space_bar.group_badge_color",
        "space_bar.group_badge_text_color",
        // App Bar: the same shape, one accent step shorter.
        "app_bar.fill_color",
        "app_bar.item_color",
        "app_bar.active_item_color",
        "app_bar.highlight_color",
        "app_bar.group_badge_color",
        "app_bar.group_badge_text_color",
        // The pair whose whole ruling is that one must not
        // compete with the other.
        "border.focused_color",
        "border.unfocused_color",
        // The state marks, which must not collapse into the
        // accent they sit beside.
        "sticky.color",
        "floating.color",
        // Twinned, because #231 says they are edited by
        // comparison.
        "drag.ghost.fill_color",
        "drag.ghost.border_color",
        "drag.drop_zone.fill_color",
        "drag.drop_zone.border_color",
    ]

    /// The four the panel deliberately does not draw, and why.
    ///
    /// A still frame cannot render a POINTER state. Drawing one
    /// item permanently hovered asserts that hover is the resting
    /// appearance — a preview teaching a behaviour the app does
    /// not have, which is #708's defect in another surface. These
    /// stay editable by swatch, and the caption labels what IS
    /// shown rather than disclaiming what is not: a caption's job
    /// is to label the picture (`gui.md` ▸ settled conventions).
    static let withheld: [String: String] = [
        "app_bar.hover_fill_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "app_bar.hover_item_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "space_bar.hover_fill_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
        "space_bar.hover_item_color": "a pointer state, which a "
            + "still frame can only draw as the resting one",
    ]

    static func drawn(at scale: PaletteSceneScale) -> Set<String> {
        switch scale {
        case .tile: return tile
        case .panel: return panel
        }
    }
}
