import AppKit

/// The held badge (#1507): an asterisk on the identifier cell's
/// top-trailing corner — a separate view, so the identifier's ink
/// framing (#1529/#1543) is untouched — and the Space's announced
/// sentence naming where it was held from. Never gated on
/// `style.stickyBadge`: the badge and the sentence are the whole
/// affordance a held Space has (#1507 ruling 5).
extension SpaceBarItemView {
    /// What the bar says about a held Space: the screen it came
    /// from, and its name there when it was renumbered.
    struct Held: Equatable {
        let screenName: String
        let originName: SpaceID?
    }

    static let heldSymbol = "asterisk"

    /// The badge family's Automatic fill; a shape, not a hue.
    func styleHeldBadge() {
        heldBadge.isHidden = held == nil
        let fill = NSColor(kiwiHex: style.groupBadgeColor)
        heldBadge.layer?.backgroundColor = fill.cgColor
        heldBadge.symbol.contentTintColor = fill.contrastingGlyph
        heldBadge.alphaValue = untintedAlpha
    }

    /// Places the badge on the identifier cell at `offset`.
    func layoutHeldBadge(onCellAt offset: CGFloat, cell: CGFloat) {
        guard !heldBadge.isHidden else { return }
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
        heldBadge.frame = backingAlignedRect(
            CGRect(
                x: cellRect.maxX - side + 1,
                y: cellRect.minY - 1,
                width: side,
                height: side
            ),
            options: .alignAllEdgesNearest
        )
        heldBadge.needsLayout = true
    }

    /// The Space's name as announced: the held frames where it is
    /// held, the plain one otherwise. The window count stays last.
    func spaceName(_ space: SpaceID, windows: Int) -> String {
        guard let held else {
            return L(
                "space_bar.item.ax.space",
                "Space %1$@, %2$d applications",
                space.raw,
                windows
            )
        }
        guard let origin = held.originName else {
            return L(
                "space_bar.item.ax.held",
                "Space %1$@, held from %2$@, not saved, "
                    + "%3$d applications",
                space.raw,
                held.screenName,
                windows
            )
        }
        return L(
            "space_bar.item.ax.held_renumbered",
            "Space %1$@, held from %2$@, where it was Space %3$@, "
                + "not saved, %4$d applications",
            space.raw,
            held.screenName,
            origin.raw,
            windows
        )
    }
}
