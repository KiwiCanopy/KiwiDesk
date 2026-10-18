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
                    before: content.before,
                    after: content.after,
                    drawn: content.drawn
                )
                item.marker =
                    state.heldSpaces[id].map {
                        .held(
                            SpaceBarItemView.Held(
                                screenName: $0.screenName,
                                originName: $0.name == id ? nil : $0.name,
                                profileName: $0.arrangement?.profileName
                            )
                        )
                    } ?? (isTemporary(id) ? .temporary : nil)
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
