import AppKit

/// The hidden App Bar mark's window count (#2567 ▸ Ruling): while
/// the pointer grows the mark, a pill in the Space mark's ink
/// carries the count beside a `macwindow` glyph — no word, so no
/// catalog key — with the bar's Fill showing at both ends. Top and
/// bottom edges read number then glyph, side edges the number above
/// it; past `sideCap` a side edge shows the plural glyph alone.
extension ShelfIndicatorSpec {
    struct Count: Equatable {
        let windows: Int
        let font: NSFont
        /// The number's ink width and its figure band's height (pt).
        let number: CGSize
        /// The glyph's drawn size, and the point size it is drawn at.
        let glyph: CGSize
        var glyphPoint: CGFloat = 0
        let horizontal: Bool

        /// Whether the number shows: always along a top or bottom
        /// edge, up to `sideCap` on a side one.
        var showsNumber: Bool {
            horizontal || windows <= ShelfIndicatorSpec.sideCap
        }

        var glyphName: String {
            showsNumber
                ? ShelfIndicatorSpec.countGlyph
                : ShelfIndicatorSpec.manyGlyph
        }

        /// The number and glyph laid out as one unit (pt), along
        /// the edge then across it.
        var content: (along: CGFloat, across: CGFloat) {
            guard showsNumber else {
                return horizontal
                    ? (glyph.width, glyph.height)
                    : (glyph.height, glyph.width)
            }
            let gap = ShelfIndicatorSpec.countGap
            return horizontal
                ? (
                    number.width + gap + glyph.width,
                    max(number.height, glyph.height)
                )
                : (
                    number.height + gap + glyph.height,
                    max(number.width, glyph.width)
                )
        }
    }

    static let countGlyph = "macwindow"
    /// A plural glyph, so a lone glyph never reads as one window.
    static let manyGlyph = "macwindow.on.rectangle"
    static let countGap: CGFloat = 2
    /// The most a side edge's pill writes as a number.
    static let sideCap = 99
    /// The glyph's largest point size.
    static let glyphSize: CGFloat = 11
    /// The Fill a grown App Bar mark keeps at each end of its
    /// pill: the Space mark's run to its first dot.
    static let fillRun: CGFloat = pad + dot + dotGap

    /// The hovered pill's depth: `labelDepth`, held inside the rim
    /// with 1 pt clear (owner, 2026-10-23).
    var pillDepth: CGFloat {
        min(
            Self.labelDepth,
            Self.depth + 2 * Self.hoverGrowth - 2 * rimWidth - 2
        )
    }

    /// The count pill's size along the edge and across it, its
    /// length floored at its depth: `pillDepth` deep on a top or
    /// bottom edge, as wide as its stack needs on a side one.
    func pill(of count: Count) -> (along: CGFloat, across: CGFloat) {
        let content = count.content
        let across =
            count.horizontal
            ? pillDepth
            : max(pillDepth, content.across + 2 * Self.labelPad)
        let along = max(content.along + 2 * Self.labelPad, across)
        return (along, across)
    }

    /// How much farther across the edge the grown mark reaches for a
    /// side edge's count pill to sit inside the rim.
    var countAcross: CGFloat {
        guard let count else { return 0 }
        let grown = Self.depth + 2 * Self.hoverGrowth
        return max(0, pill(of: count).across + 2 * rimWidth + 2 - grown)
    }

    /// `windows` measured in `font`, its glyph shrunk only to fit
    /// a top or bottom pill with 1 pt clear.
    @MainActor static func count(
        _ windows: Int,
        font: NSFont,
        edge: AppBarEdge,
        pillDepth: CGFloat
    ) -> Count {
        let figures = BarTextGlyph.span(of: .figures, font: font)
        let number = CGSize(
            width: ceil(
                BarTextGlyph.metrics("\(windows)", font: font).ink.width
            ),
            height: ceil(figures.upperBound - figures.lowerBound)
        )
        let horizontal = edge.isHorizontal
        let probe = Count(
            windows: windows,
            font: font,
            number: number,
            glyph: .zero,
            horizontal: horizontal
        )
        // Across a top or bottom pill the glyph keeps 1 pt clear.
        let room = horizontal ? pillDepth - 2 : .greatestFiniteMagnitude
        var size = glyphSize
        var image = countSymbol(probe.glyphName, size: size)
        while let drawn = image, drawn.size.height > room, size > 4 {
            size -= 0.5
            image = countSymbol(probe.glyphName, size: size)
        }
        return Count(
            windows: windows,
            font: font,
            number: number,
            glyph: image?.size ?? .zero,
            glyphPoint: size,
            horizontal: horizontal
        )
    }

    /// How the grown mark exceeds the plain hover growth: along the
    /// edge for a Space name's or the count's pill, across it for a
    /// side edge's count — the one value every reader of the grown
    /// plate takes (`BarMotion.hoverPlate`), the reveal's included.
    struct Growth: Equatable, Sendable {
        var widen: CGFloat = 0
        var across: CGFloat = 0

        static let none = Growth()
    }

    var growth: Growth { Growth(widen: labelExtra, across: countAcross) }

    /// The count's SF Symbol at `size`, made once per name and size:
    /// every bar refresh measures it.
    @MainActor static func countSymbol(
        _ name: String,
        size: CGFloat
    ) -> NSImage? {
        let key = "\(name)@\(size)"
        if let known = symbols[key] { return known }
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?
        .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
        if symbols.count > 64 { symbols.removeAll() }
        symbols[key] = image
        return image
    }

    @MainActor private static var symbols: [String: NSImage] = [:]
}
