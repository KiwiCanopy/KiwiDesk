import AppKit

/// The Space marker, drawn inline after the identifier in the
/// identifier's own ink — a separate view, so the identifier's ink
/// framing (#1529/#1543) is untouched — and the Space's announced
/// sentence: a held Space (#1507) wears two screens, naming where
/// it was held from, and a temporary one (#1790) an hourglass. A
/// Space is never both, so they share the slot. Never gated on
/// `style.stickyBadge`: it is no window-state badge, and the marker
/// and the sentence are the whole affordance either has.
extension SpaceBarItemView {
    /// Which marker a Space wears — one value, so a Space cannot
    /// carry two.
    enum Marker: Equatable {
        case held(Held)
        case temporary

        /// The SF Symbol it draws: outlines, so each reads as an
        /// object rather than a mark to decode.
        var symbol: String {
            switch self {
            case .held: return "display.2"
            case .temporary: return "hourglass"
            }
        }
    }

    /// Where this item's Space was held from, if it is held.
    var held: Held? {
        if case .held(let held) = marker { return held }
        return nil
    }

    /// What the bar says about a held Space: the screen it came
    /// from, and its name there when it was renumbered.
    struct Held: Equatable {
        let screenName: String
        let originName: SpaceID?
    }

    /// The symbol the marker draws now, if any.
    var markerSymbol: String? {
        markerView.isHidden ? nil : marker?.symbol
    }

    /// The marker's side along the bar: a little taller than the
    /// identifier's digits, so a thin glyph still reads.
    static func markerSide(cell: CGFloat) -> CGFloat {
        (cell * 0.55).rounded()
    }

    /// How much a marker adds to the item's length — its side and
    /// the gap before it; zero without one.
    static func markerLength(cell: CGFloat, marked: Bool) -> CGFloat {
        marked ? markerSide(cell: cell) + 2 : 0
    }

    /// Monochrome at regular weight, in the identifier's own ink,
    /// dimming and lighting with it.
    func styleMarker() {
        markerView.isHidden = marker == nil
        guard let marker else { return }
        markerView.image = NSImage(
            systemSymbolName: marker.symbol,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 0, weight: .regular)
                .applying(.preferringMonochrome())
        )
        switch spaceGlyph {
        case .symbol:
            markerView.contentTintColor = stateColor
            markerView.alphaValue = 1
        case .text(_, let tinted):
            markerView.contentTintColor = tinted ? stateColor : .labelColor
            markerView.alphaValue = tinted ? 1 : untintedAlpha
        }
    }

    /// Places the marker after the identifier cell ending at
    /// `offset`, centred across the item on its alignment rect so
    /// a glyph's uneven padding does not pull it off centre.
    func layoutMarker(after offset: CGFloat, cell: CGFloat) {
        guard !markerView.isHidden else { return }
        let side = Self.markerSide(cell: cell)
        let lead = offset + 2
        let across = ((horizontal ? bounds.height : bounds.width) - side) / 2
        let rect =
            horizontal
            ? CGRect(x: lead, y: across, width: side, height: side)
            : CGRect(x: across, y: lead, width: side, height: side)
        markerView.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
    }

    /// The Space's name as announced: the held frames where it is
    /// held, the temporary one where it is temporary, the plain one
    /// otherwise. The window count stays last.
    func spaceName(_ space: SpaceID, windows: Int) -> String {
        if marker == .temporary {
            return L(
                "space_bar.item.ax.temporary",
                "Space %1$@, temporary, windows: %2$d",
                space.raw,
                windows
            )
        }
        guard let held else {
            return L(
                "space_bar.item.ax.space",
                "Space %1$@, windows: %2$d",
                space.raw,
                windows
            )
        }
        guard let origin = held.originName else {
            return L(
                "space_bar.item.ax.held",
                "Space %1$@, held from %2$@, not saved, "
                    + "windows: %3$d",
                space.raw,
                held.screenName,
                windows
            )
        }
        return L(
            "space_bar.item.ax.held_renumbered",
            "Space %1$@, held from %2$@, where it was Space %3$@, "
                + "not saved, windows: %4$d",
            space.raw,
            held.screenName,
            origin.raw,
            windows
        )
    }
}
