import AppKit

/// What the menu bar item draws for the active layer and, while
/// the Space Bar is off, for the Space each screen shows (#1413).
/// The one derivation of the layer's menu-bar glyph — the bus
/// sink that used to hand the GUI a raw icon string is retired,
/// so the switch cannot draw one layer two ways. Core hands
/// structure; the GUI draws and names it (#96).
public struct StatusSpaceMark: Equatable {
    /// The bar's own identifier ladder, carried across with its
    /// tint bit: an untinted text glyph is an emoji, which takes
    /// no template tint.
    public enum Glyph: Equatable {
        case symbol(String)
        case text(String, tinted: Bool)

        public var keepsColour: Bool {
            if case .text(_, tinted: false) = self { return true }
            return false
        }

        init(_ identifier: SpaceBarItemView.Identifier) {
            switch identifier {
            case .symbol(let name): self = .symbol(name)
            case .text(let text, let tinted):
                self = .text(text, tinted: tinted)
            }
        }
    }

    public struct Layer: Equatable {
        public let name: String
        /// The icon, or the monogram where there is none — which
        /// `hasIcon` tells apart, since the bar-on item keeps the
        /// brand glyph for an icon-less layer (owner ruling).
        public let glyph: Glyph
        public let hasIcon: Bool
    }

    public struct Screen: Equatable {
        public let display: Display
        public let space: SpaceID
        public let glyph: Glyph
    }

    /// nil on `default`, which has no icon.
    public let layer: Layer?
    /// One per display showing a Space, unordered — the GUI
    /// ranks them (`DeskOrder`). Empty while the bar is on.
    public let screens: [Screen]
}

extension KiwiCore {
    func statusSpaceMark() -> StatusSpaceMark {
        let layer = activeLayerGlyph().map {
            StatusSpaceMark.Layer(
                name: $0.name,
                glyph: StatusSpaceMark.Glyph($0.glyph),
                hasIcon: $0.hasIcon
            )
        }
        guard !tiler.settings.spaceBarStyle.enabled else {
            return StatusSpaceMark(layer: layer, screens: [])
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
                glyph: StatusSpaceMark.Glyph(spaceGlyph(for: space))
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
