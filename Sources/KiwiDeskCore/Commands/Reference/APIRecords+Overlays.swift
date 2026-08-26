import Foundation

/// `drag.*`, `border.*`, `sticky.*`, `floating.*`, `mouse.*`
/// and `quit.*` — the overlays and the odd single-setting
/// namespaces (#1033).
///
/// Every record here is `.todo()` until phase 2 fills it. The
/// colour setters take `.color`; `sticky.set_color` and
/// `floating.set_color` also accept an EMPTY string, which
/// clears the mark colour back to the palette's — that belongs
/// in the summary, not in a new argument kind.
extension APIReference {
    static let dragRecords: [String: APIRecord] = [
        "set_ghost_enabled": .todo(),
        "set_ghost_border": .todo(),
        "set_ghost_border_width": .todo(),
        "set_ghost_border_alignment": .todo(),
        "set_ghost_border_color": .todo(),
        "set_ghost_fill": .todo(),
        "set_ghost_fill_color": .todo(),
        "set_drop_zone_enabled": .todo(),
        "set_drop_zone_border": .todo(),
        "set_drop_zone_border_width": .todo(),
        "set_drop_zone_border_alignment": .todo(),
        "set_drop_zone_border_color": .todo(),
        "set_drop_zone_fill": .todo(),
        "set_drop_zone_fill_color": .todo(),
        "set_corner_radius": .todo(),
    ]

    static let borderRecords: [String: APIRecord] = [
        "set_enabled": .todo(),
        "set_width": .todo(),
        "set_focused_color": .todo(),
        "set_unfocused_enabled": .todo(),
        "set_unfocused_color": .todo(),
        "set_corner_style": .todo(),
        "set_glow": .todo(),
        "set_glow_size": .todo(),
        "set_draw_order": .todo(),
        "fit_gaps": .todo(),
    ]

    static let stickyRecords: [String: APIRecord] = [
        "set_mark": .todo(),
        "set_color": .todo(),
    ]

    static let floatingRecords: [String: APIRecord] = [
        "set_color": .todo()
    ]

    static let mouseRecords: [String: APIRecord] = [
        "set_follows_focus": .todo()
    ]

    static let quitRecords: [String: APIRecord] = [
        "set_layout": .todo(),
        "set_grid_target_depth": .todo(),
    ]
}
