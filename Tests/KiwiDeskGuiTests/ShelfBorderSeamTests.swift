import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shelf's border is painted in ONE place (#1679, bars.md):
/// `ShelfBorder.paint` is the only Core reader of the drawn width,
/// and inside `Bar/` the only layer-border writes beside it are the
/// active indicator's. A rim drawn beside the painter would skip
/// the switch, the clamp or the surface rule.
@Suite("Shelf border seam")
struct ShelfBorderSeamTests {
    private static let home = "ShelfBorder.swift"

    private static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Where the width is declared, and the one painter.
    private static let readers: Set<String> = [
        "KiwiShelf.swift", home,
    ]

    @Test("Only the painter reads the drawn border width")
    func onePainterReadsTheWidth() throws {
        var hits: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("drawnBorderWidth") {
                hits.insert(file.lastPathComponent)
            }
        }
        #expect(scanned >= 200, "scanned \(scanned) files")
        // Equality, so the painter must still read it too.
        #expect(hits == Self.readers, "\(hits)")
    }

    /// Whether an indicator stands a rim down is `ShelfBorder.yields`'
    /// alone (#1924): in Core only it asks `strokesBoxEdge`, beside
    /// the property's own declaration.
    @Test("Only the painter asks whether an indicator strokes the edge")
    func onePainterAsksTheEdge() throws {
        var hits: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("strokesBoxEdge") {
                hits.insert(file.lastPathComponent)
            }
        }
        #expect(hits == [Self.home, "AppBarStyle+Enums.swift"], "\(hits)")
    }

    private static let enums = "AppBarStyle+Enums.swift"

    /// Whether an indicator draws an outline is `drawsOutline`'s
    /// alone (#2029): across Core and the GUI only its declaration
    /// compares to `.outline`, so a third kind or a change to
    /// which kinds outline answers everywhere at once. Exhaustive
    /// `case .outline:` dispatches are the compiler's, not this.
    @Test("Only drawsOutline compares an indicator to .outline")
    func oneHomeSpellsTheOutline() throws {
        let pattern = try NSRegularExpression(
            pattern: #"[!=]=\s*\.outline\b|\.outline\s*[!=]="#
        )
        let gui = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var hits: Set<String> = []
        for root in [Self.coreRoot, gui] {
            var scanned = 0
            for file in try SourceScan.swiftSources(under: root) {
                scanned += 1
                let source = try SourceScan.strippedSource(at: file)
                let range = NSRange(source.startIndex..., in: source)
                if pattern.firstMatch(in: source, range: range) != nil {
                    hits.insert(file.lastPathComponent)
                }
            }
            // A floor per root, so neither tree goes unscanned.
            #expect(scanned >= 200, "\(root.path): \(scanned)")
        }
        #expect(hits == [Self.enums], "\(hits)")

        let url = Self.coreRoot
            .appendingPathComponent("Layouts")
            .appendingPathComponent(Self.enums)
        let body = SourceScan.declarationBody(
            after: "var strokesBoxEdge: Bool",
            in: try SourceScan.strippedSource(at: url)
        )
        #expect(body?.contains("drawsOutline") == true, "\(body ?? "")")
        #expect(body?.contains(".outline") == false, "\(body ?? "")")
    }

    /// `strokesBoxEdge` may derive from `drawsOutline` only while
    /// a rimmed box is exactly where the outline hugs (#2029).
    @Test("A rimmed box is where the outline hugs, on every shape")
    func rimmedBoxIsWhereTheOutlineHugs() {
        var shelf = KiwiShelf()
        let styles = type(of: shelf.backgroundStyle).allCases
        let fits = type(of: shelf.backgroundFit).allCases
        for style in styles {
            for fit in fits {
                shelf.backgroundStyle = style
                shelf.backgroundFit = fit
                #expect(
                    ShelfBorder.rims(.box, on: shelf)
                        == BarAccent.hugsBox(shelf),
                    "\(style) \(fit)"
                )
            }
        }
    }

    /// The drop ring morphs into the outline, so it hugs where
    /// the outline does, asking `BarAccent.hugsBox` (#1924).
    @Test("The drop ring asks where the outline hugs")
    func dropRingAsksTheOutline() throws {
        let url = Self.coreRoot
            .appendingPathComponent("Bar")
            .appendingPathComponent("SpaceBarItemView+DragDrop.swift")
        let source = try SourceScan.strippedSource(at: url)
        #expect(source.contains("= BarAccent.hugsBox(style.shelf)"))
        #expect(!source.contains("hasBox"))
    }

    /// The active indicator's outline, the one other layer border
    /// `Bar/` strokes: file and write count per channel, so a new
    /// write — even one spelled like the accent's — reds until it
    /// is ruled. The width is counted on its own: CALayer's default
    /// border colour is opaque black, so a width alone draws a rim.
    /// The App Bar item's width count includes its own layer's
    /// reset to 0, which draws nothing; so does the front chip's
    /// indicator (#1856), the Space item's accent laid on the chip.
    private static let allowedColor: [String: Int] = [
        "AppBarItemView+Paint.swift": 1,
        "SpaceBarItemView+Style.swift": 1,
        "SpaceBarOverlay+FrontAccent.swift": 1,
    ]
    private static let allowedWidth: [String: Int] = [
        "AppBarItemView+Paint.swift": 3,
        "SpaceBarItemView+Style.swift": 2,
        "SpaceBarOverlay+FrontAccent.swift": 2,
    ]

    /// Per `Bar/` file, how many assignments to `property` it
    /// makes, whatever the spacing, never a `==` comparison.
    private static func writes(
        of property: String
    ) throws -> [String: Int] {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(property)\\s*=(?!=)"
        )
        let bar = coreRoot.appendingPathComponent("Bar")
        var writes: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: bar) {
            let source = try SourceScan.strippedSource(at: file)
            let count = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            if count > 0 { writes[file.lastPathComponent] = count }
        }
        return writes
    }

    /// A layer border in `Bar/` is the active indicator's or the
    /// painter's; any other one is a second rim.
    @Test(
        "Bar/ strokes a layer border only in the painter or accent",
        arguments: ["borderColor", "borderWidth"]
    )
    func noSecondRim(property: String) throws {
        var writes = try Self.writes(of: property)
        #expect(
            writes.removeValue(forKey: Self.home) != nil,
            "the painter no longer writes \(property)"
        )
        let allowed =
            property == "borderColor"
            ? Self.allowedColor : Self.allowedWidth
        #expect(writes == allowed, "\(property): \(writes)")
    }
}
