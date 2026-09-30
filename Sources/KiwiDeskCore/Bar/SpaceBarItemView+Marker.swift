import AppKit

/// The Space marker on the identifier cell's top-trailing corner —
/// a separate view, so the identifier's ink framing (#1529/#1543)
/// is untouched — and the Space's announced sentence: a held Space
/// (#1507) wears a display, naming where it was held from, and a
/// temporary one (#1790) an hourglass. A Space is never both, so
/// they share the slot. Never gated on `style.stickyBadge`: the
/// marker and the sentence are the whole affordance either has.
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
            case .held: return "display"
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

    /// The badge family's Automatic fill; a shape, not a hue. The
    /// symbol draws monochrome at regular weight.
    func styleMarkerBadge() {
        markerBadge.isHidden = marker == nil
        if let marker, markerBadge.symbolName != marker.symbol {
            markerBadge.show(
                symbol: marker.symbol,
                configuration: NSImage.SymbolConfiguration(
                    pointSize: 0,
                    weight: .regular
                ).applying(.preferringMonochrome())
            )
        }
        let fill = NSColor(kiwiHex: style.groupBadgeColor)
        markerBadge.layer?.backgroundColor = fill.cgColor
        markerBadge.symbol.contentTintColor = fill.contrastingGlyph
        markerBadge.alphaValue = untintedAlpha
    }

    /// Places the marker on the identifier cell at `offset`.
    func layoutMarkerBadge(onCellAt offset: CGFloat, cell: CGFloat) {
        guard !markerBadge.isHidden else { return }
        let side = StateBadgeMetrics.side(cell: cell)
        let cellRect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        markerBadge.frame = backingAlignedRect(
            CGRect(
                x: cellRect.maxX - side + 1,
                y: cellRect.minY - 1,
                width: side,
                height: side
            ),
            options: .alignAllEdgesNearest
        )
        markerBadge.needsLayout = true
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
