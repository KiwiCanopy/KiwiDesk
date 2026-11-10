import AppKit

/// What the menu bar item draws for the active layer and, while
/// the Space Bar is off, for the Space each screen shows (#1413).
/// The layer's menu-bar glyph has this one derivation, over
/// `activeLayerGlyph`. Core hands structure; the GUI draws and
/// names it (#96).
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

        init(_ identifier: SpaceGlyph) {
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
        /// Whether the Space has tiling off (#3008): the mark wears
        /// the Space Bar's `pause` marker.
        public var tilingOff = false
    }

    /// The SF Symbol a tiling-off Space wears (#3008): the Space
    /// Bar's marker, the menu-bar mark and the menus read this one.
    public static let tilingOffSymbol = "pause"

    /// nil on `default`, which has no icon.
    public let layer: Layer?
    /// One per display showing a Space, unordered — the GUI
    /// ranks them (`DeskOrder`). A screen is listed only where its
    /// edge fold draws no Space Bar at rest (#1413, #761).
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
        let screens = state.workspaces.allDisplays.compactMap {
            display -> StatusSpaceMark.Screen? in
            // SHOWN, not focused (#1214): the item names what
            // each screen is displaying.
            guard
                let space = state.workspaces.currentSpace(
                    on: display.id
                )
            else { return nil }
            let mode = state.workspaces[space]?.mode ?? .bsp
            // A tiling-off Space whose tick hides the bars reads its
            // Space Bar Hidden (#3008, #3151, bars.md).
            guard
                !shelfSettings(on: display.id).drawsAtRest(
                    .space,
                    in: mode,
                    on: display.fingerprint
                )
            else { return nil }
            var screen = StatusSpaceMark.Screen(
                display: display,
                space: space,
                glyph: StatusSpaceMark.Glyph(spaceGlyph(for: space))
            )
            screen.tilingOff = isTilingOff(space)
            return screen
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
