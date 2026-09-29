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
                let content = spaceBarApps(
                    in: space,
                    style: style,
                    held: spaceBars.heldStrip(of: id)
                )
                if style.hideEmpty, content.apps.isEmpty,
                    id != current
                {
                    return nil
                }
                var item = SpaceBarOverlay.Item(
                    space: id,
                    spaceGlyph: Self.spaceBarLabel(
                        identifier: spaceIdentifier(for: id),
                        mode: space.mode,
                        label: style.itemLabel
                    ),
                    apps: content.apps,
                    active: id == current,
                    overflow: content.after,
                    // Only the active space carries the system
                    // focus, and on a second screen `current` is
                    // not it (#1214): an inactive space's
                    // `focused` is just its own last-focused
                    // window, so tinting a `+n` off it marks a
                    // focus no glyph on that bar wears.
                    focusInOverflow: id == activeSpace?.id
                        && content.focusAfter,
                    overflowBefore: content.before,
                    focusBefore: id == activeSpace?.id
                        && content.focusBefore,
                    strip: content.window
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

    /// What names a Space item (#1535): its identifier, or its
    /// layout's symbol. Pure — the bar and the Bars preview both
    /// take it, so the preview cannot label a Space its own way.
    public static func spaceBarLabel(
        identifier: SpaceGlyph,
        mode: LayoutMode,
        label: SpaceBarStyle.ItemLabel
    ) -> SpaceGlyph {
        switch label {
        case .identifier: return identifier
        case .layout: return .symbol(mode.symbol)
        }
    }
}
