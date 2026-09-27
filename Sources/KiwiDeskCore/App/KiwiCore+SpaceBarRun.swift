import AppKit

/// The Space Bar's run, split from `KiwiCore+SpaceBarItems` for
/// the file size: one item per Space the display holds, the ones
/// its screen does not show collapsed to `inactive_content`
/// (#1683). Read from snapshotted state — no AX calls.
extension KiwiCore {
    /// The display's Spaces in profile order, each with its
    /// identifier and app glyphs. `hide_empty` drops empty
    /// spaces except the current one (it always stays — cold
    /// start must not collapse the strip).
    func spaceBarItems(
        display: DisplayID,
        style: SpaceBarLook
    ) -> [SpaceBarOverlay.Item] {
        // SHOWN, not focused: which Space this screen is
        // displaying. The presence and focus questions below
        // take the one active Space instead (#1214).
        let current = state.workspaces.currentSpace(on: display)
        return state.workspaces.spaces(on: display)
            .compactMap { id in
                guard let space = state.workspaces[id] else {
                    return nil
                }
                let (apps, overflow, focusHidden) = spaceBarApps(
                    in: space,
                    style: style
                )
                if style.hideEmpty, apps.isEmpty,
                    id != current
                {
                    return nil
                }
                var item = SpaceBarOverlay.Item(
                    space: id,
                    spaceGlyph: spaceIdentifier(for: id),
                    apps: apps,
                    active: id == current,
                    overflow: overflow,
                    // Only the active space carries the system
                    // focus, and on a second screen `current` is
                    // not it (#1214): an inactive space's
                    // `focused` is just its own last-focused
                    // window, so tinting the `+n` off it marks a
                    // focus no glyph on that bar wears.
                    focusInOverflow: id == activeSpace?.id
                        && focusHidden
                )
                item.held = state.heldSpaces[id].map {
                    SpaceBarItemView.Held(
                        screenName: $0.screenName,
                        originName: $0.name == id ? nil : $0.name
                    )
                }
                // After the `hide_empty` verdict, which reads
                // the glyphs the collapse drops.
                return item.collapsed(to: style.inactiveContent)
            }
    }
}
