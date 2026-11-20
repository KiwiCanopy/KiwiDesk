import AppKit

/// What the menu bar item draws for the active layer and the Space
/// each screen shows, as `kiwishelf.menu_bar_icon` picks (#1413,
/// #3532).
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
        /// The Space's layout where the glyph is its symbol (#3532),
        /// so VoiceOver names the layout; nil where it is the name.
        public var layout: LayoutMode?
    }

    /// The SF Symbol a tiling-off Space wears (#3008): the Space
    /// Bar's marker, the menu-bar mark and the menus read this one.
    public static let tilingOffSymbol = "pause"

    /// nil on `default`, which has no icon.
    public let layer: Layer?
    /// One per display showing a Space, unordered — the GUI
    /// ranks them (`DeskOrder`). Under `auto` a screen is listed
    /// only where its edge fold draws no Space Bar at rest (#1413,
    /// #761); `identifier` and `layout` list every screen, `logo`
    /// none (#3532).
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
        let icon = tiler.settings.kiwishelf.menuBarIcon
        guard icon != .logo else {
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
            let mode = state.workspaces[space]?.mode ?? .bsp
            // A tiling-off Space whose tick hides the bars reads its
            // Space Bar Hidden (#3008, #3151, bars.md).
            if icon == .auto,
                shelfSettings(on: display.id).drawsAtRest(
                    .space,
                    in: mode,
                    on: display.fingerprint
                )
            {
                return nil
            }
            let label: SpaceBarStyle.ItemLabel =
                icon == .layout ? .layout : .identifier
            var screen = StatusSpaceMark.Screen(
                display: display,
                space: space,
                glyph: StatusSpaceMark.Glyph(
                    Self.spaceBarLabel(
                        identifier: spaceGlyph(for: space),
                        mode: mode,
                        label: label
                    )
                )
            )
            screen.tilingOff = isTilingOff(space)
            screen.layout = label == .layout ? mode : nil
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
