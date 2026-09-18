import AppKit

/// What the menu bar item shows in the Space Bar's stead (#1413):
/// the active layer's glyph while one other than `default` is
/// active, then the Space each screen shows. One `NSStatusItem`
/// is mirrored into every screen's menu bar, so it cannot show a
/// screen its own Space — it lists them all instead, and the GUI
/// ranks them (`DeskOrder`). Core hands structure; the GUI draws
/// and names it (#96).
public struct StatusSpaceMark: Equatable {
    public struct Layer: Equatable {
        public let name: String
        public let glyph: SpaceMark
    }

    public struct Screen: Equatable {
        public let display: Display
        public let space: SpaceID
        public let glyph: SpaceMark
    }

    /// nil on `default`, which has no icon.
    public let layer: Layer?
    /// One per display showing a Space, unordered.
    public let screens: [Screen]
}

extension KiwiCore {
    /// The mark for the current state, or nil while the Space Bar
    /// is on — the item then keeps its brand or layer icon, as
    /// before (owner ruling on #1413).
    func statusSpaceMark() -> StatusSpaceMark? {
        guard !tiler.settings.spaceBarStyle.enabled else {
            return nil
        }
        let screens = state.workspaces.allDisplays.compactMap {
            display -> StatusSpaceMark.Screen? in
            // SHOWN, not focused (#1214): the item names what
            // each screen is displaying.
            guard
                let space = state.workspaces.currentSpace(
                    on: display.id
                )
            else { return nil }
            return StatusSpaceMark.Screen(
                display: display,
                space: space,
                glyph: spaceMark(for: space)
            )
        }
        guard !screens.isEmpty else { return nil }
        var layer: StatusSpaceMark.Layer?
        if let item = spaceBarLayerItem(),
            case .layer(let name) = item.identity
        {
            layer = StatusSpaceMark.Layer(
                name: name,
                glyph: SpaceMark(item.spaceGlyph)
            )
        }
        return StatusSpaceMark(layer: layer, screens: screens)
    }

    /// Publishes the mark off the bar's own refresh, so every
    /// trigger the bar has — retile, layer switch, Desktop
    /// settle — reaches the menu bar too.
    func publishStatusSpaceMark() {
        spaceBars.publishStatusMark(statusSpaceMark())
    }
}

extension SpaceMark {
    /// The bar's identifier without its tint bit, which
    /// `isEmoji` answers where a renderer needs it.
    init(_ identifier: SpaceBarItemView.Identifier) {
        switch identifier {
        case .symbol(let name): self = .symbol(name)
        case .text(let text, _): self = .text(text)
        }
    }

    /// Whether the mark keeps its own colour: an emoji takes no
    /// template tint, so an image carrying one cannot be one.
    public var isEmoji: Bool {
        guard case .text(let text) = self else { return false }
        return KiwiCore.isEmoji(text)
    }
}
