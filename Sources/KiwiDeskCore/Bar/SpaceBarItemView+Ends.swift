import AppKit

/// A Space item's rounded ends (#1763): the clearance its glyph
/// cell needs, at every rounded end (`KiwiShelf.roundsItemEnds`)
/// alike once an icon-like glyph sits at either end — a symbol
/// identifier, app glyphs or a `+N` disc, a corner badge on the
/// identifier — so the content centres (#1856, owner 2026-10-01,
/// reversing 2026-09-29's per-end pad). A text identifier needs
/// none, and neither does a lone glyph that fits the round end.
extension SpaceBarItemView {
    /// Whether the identifier cell carries a corner badge — a
    /// collapse's count or the Space marker, at its trailing top.
    static func badgesIdentifier(collapsed: Bool, marked: Bool) -> Bool {
        collapsed || marked
    }

    /// Whether the trailing end holds an icon-like glyph: app
    /// glyphs, or the identifier's corner badge on a horizontal
    /// bar — the one reading the item and its measurement share.
    static func endsInIcon(
        appCount: Int,
        badged: Bool,
        horizontal: Bool
    ) -> Bool {
        appCount > 0 || (badged && horizontal)
    }

    /// Whether the leading end holds an icon-like glyph: a symbol
    /// identifier, or its corner badge at the top of a vertical bar.
    static func leadsWithIcon(
        _ glyph: SpaceGlyph,
        badged: Bool,
        horizontal: Bool
    ) -> Bool {
        if case .symbol = glyph { return true }
        return badged && !horizontal
    }

    /// The identifier when it is the item's only content — no app
    /// glyph, no corner badge — else nil.
    static func lone(
        _ glyph: SpaceGlyph,
        appCount: Int,
        badged: Bool
    ) -> SpaceGlyph? {
        appCount == 0 && !badged ? glyph : nil
    }

    /// Whether a lone identifier, centred in a chip that pads no
    /// end, keeps its ink inside the chip's rounded box: a symbol
    /// as it draws — at the identifier's point size, scaled down
    /// into its cell as the image view does; text, whose ink
    /// clears a curve by ruling, always. Memoized, since every
    /// length read asks.
    static func fitsRoundEnd(
        _ glyph: SpaceGlyph,
        look: SpaceBarLook,
        depth: CGFloat
    ) -> Bool {
        guard case .symbol(let name) = glyph else { return true }
        let size = look.identifierFontSize(forDepth: depth)
        let cell = cell(contentDepth: look.contentDepth(forDepth: depth))
        let length = autoLength(
            appCount: 0,
            contentDepth: look.contentDepth(forDepth: depth),
            glyphGap: 0,
            ends: .zero
        )
        let radius = min(
            look.resolvedCornerRadius(forThickness: depth),
            min(length, depth) / 2
        )
        let horizontal = look.edge.isHorizontal
        let key =
            [name, "\(size)", "\(cell)", "\(length)", "\(depth)"]
            .joined(separator: "|") + "|\(radius)|\(horizontal)"
            as NSString
        if let known = fitCache.object(forKey: key) {
            return known.boolValue
        }
        // The verdict is already `.symbol`; a name that draws
        // nothing has no ink to clear.
        let image =
            NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            )?.size ?? .zero
        let scale = min(
            1,
            cell / max(image.width, 1),
            cell / max(image.height, 1)
        )
        // Along the bar and across it: a vertical bar's length
        // runs along y.
        let along = (horizontal ? image.width : image.height) * scale
        let across = (horizontal ? image.height : image.width) * scale
        // The ink's corner past the box's straight run, against
        // the corner's own circle.
        let dx = max(0, along / 2 - (length / 2 - radius))
        let dy = max(0, across / 2 - (depth / 2 - radius))
        let fits = dx * dx + dy * dy <= radius * radius
        fitCache.setObject(NSNumber(value: fits), forKey: key)
        return fits
    }

    private static let fitCache = NSCache<NSString, NSNumber>()

    private var badged: Bool {
        Self.badgesIdentifier(
            collapsed: collapse != nil,
            marked: marker != nil
        )
    }

    /// The extra end padding this item's rounded ends owe.
    var ends: ItemEnds {
        Self.ends(
            look: style,
            depth: depth,
            first: isFirstInRun,
            last: isLastInRun,
            leadsWithIcon: Self.leadsWithIcon(
                spaceGlyph,
                badged: badged,
                horizontal: style.edge.isHorizontal
            ),
            endsInIcon: Self.endsInIcon(
                appCount: apps.count,
                badged: badged,
                horizontal: style.edge.isHorizontal
            ),
            lone: Self.lone(
                spaceGlyph,
                appCount: apps.count,
                badged: badged
            )
        )
    }

    /// A rounded end's clearance for a Space Bar glyph cell, which
    /// the items and the front-app chip share.
    static func endClearance(look: SpaceBarLook, depth: CGFloat) -> CGFloat {
        let cell = cell(contentDepth: look.contentDepth(forDepth: depth))
        return KiwiShelf.endClearance(
            radius: look.resolvedCornerRadius(forThickness: depth),
            crossOffset: (depth - cell) / 2
        )
    }

    /// The end insets of an item at its place in the run — the one
    /// reading `autoLength`'s callers and `layout()` share.
    static func ends(
        look: SpaceBarLook,
        depth: CGFloat,
        first: Bool,
        last: Bool,
        leadsWithIcon: Bool,
        endsInIcon: Bool,
        lone: SpaceGlyph?
    ) -> ItemEnds {
        let fits = lone.map {
            fitsRoundEnd($0, look: look, depth: depth)
        }
        guard leadsWithIcon || endsInIcon, fits != true
        else { return .zero }
        return look.shelf.itemEnds(
            clearance: endClearance(look: look, depth: depth),
            first: first,
            last: last,
            outlined: look.activeIndicator == .outline
        )
    }
}
