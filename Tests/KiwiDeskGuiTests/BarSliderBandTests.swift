import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A bar slider edge Core also clamps is DERIVED from the Core
/// constant, and every consumer reads the one home (#1359,
/// gui.md ▸ the GUI curates).
///
/// A restated floor of 30 shipped for two months over a Core
/// floor of 20, and the gap was a legal stored value the GUI
/// could not reach. Two numbers in files nothing compared: the
/// first clause compares them by reading the DECLARATION, since
/// a value equality is satisfied by a restated `20...80` on the
/// day it is written. The second locates each consumer by its
/// census arm — the `case .appBarThickness:` the row builder
/// switches on — never by the row's own `L()` key, which a
/// relabel takes out of a scan without a red.
@Suite("Bar slider bands")
struct BarSliderBandTests {
    private static let bars = "Sources/KiwiDesk/Settings/Components/Bars"

    /// The `static let <name>` (or `static func <name>`)
    /// declaration in `BarSliderBands`, through the end of its
    /// initializer or body.
    private func declaration(
        of name: String,
        keyword: String = "let"
    ) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars)
            .appendingPathComponent("BarSliderBands.swift")
        let text = try SourceScan.strippedSource(at: file)
        let needle = "static \(keyword) \(name)"
        let start = try #require(text.range(of: needle))
        let rest = text[start.lowerBound...]
        let end =
            rest.range(of: "\n\n")?.lowerBound
            ?? rest.range(of: "\n}")?.lowerBound
            ?? rest.endIndex
        return String(rest[..<end])
    }

    @Test("the thickness floor is Core's, by derivation")
    func thicknessFloorIsDerived() throws {
        let band = BarSliderBands.thickness
        #expect(band.lowerBound == Double(KiwiShelf.minThickness))
        #expect(band.contains(Double(KiwiShelf().thickness)))
        let declared = try declaration(of: "thickness")
        #expect(declared.contains("KiwiShelf.minThickness"))
    }

    @Test("the spring delay band is Core's range, by derivation")
    func springDelayIsDerived() throws {
        let band = BarSliderBands.springDelaySeconds
        let core = SpaceBarStyle.springDelayRange
        #expect(band.lowerBound * 1000 == Double(core.lowerBound))
        #expect(band.upperBound * 1000 == Double(core.upperBound))
        let declared = try declaration(of: "springDelaySeconds")
        #expect(declared.contains("SpaceBarStyle.springDelayRange"))
    }

    @Test("the margin floor is Core's, by derivation")
    func marginFloorIsDerived() throws {
        let band = BarSliderBands.margin
        #expect(band.lowerBound == Double(KiwiShelf.minMargin))
        #expect(band.contains(Double(KiwiShelf().outerMargin)))
        #expect(band.contains(Double(KiwiShelf().innerMargin)))
        let declared = try declaration(of: "margin")
        #expect(declared.contains("KiwiShelf.minMargin"))
    }

    /// The two gap rows sit beside each other and stop alike
    /// (#1695): each floor is Core's, the top the one curated
    /// `gapCeiling` — read off both declarations, since a
    /// restated `40` in either matches today's value.
    @Test("the gap bands derive their floors and share one ceiling")
    func gapBandsShareOneCeiling() throws {
        let item = BarSliderBands.itemGap
        let glyph = BarSliderBands.glyphGap
        #expect(item.lowerBound == Double(KiwiShelf.minItemGap))
        #expect(glyph.lowerBound == Double(SpaceBarStyle.minGlyphGap))
        #expect(item.upperBound == glyph.upperBound)
        #expect(item.contains(Double(KiwiShelf().itemGap)))
        #expect(glyph.contains(Double(SpaceBarStyle().glyphGap)))
        let itemDeclared = try declaration(of: "itemGap")
        #expect(itemDeclared.contains("KiwiShelf.minItemGap"))
        #expect(itemDeclared.contains("gapCeiling"))
        let glyphDeclared = try declaration(of: "glyphGap")
        #expect(glyphDeclared.contains("SpaceBarStyle.minGlyphGap"))
        #expect(glyphDeclared.contains("gapCeiling"))
    }

    /// The floor is Core's content floor and the ceiling the
    /// draft's thickness, past which `contentDepth` draws the
    /// thickness whatever the value (#1713).
    @Test("the glyph size band derives from Core and the thickness")
    func glyphSizeIsDerived() throws {
        for thickness: CGFloat in [KiwiShelf.minThickness, 40, 80] {
            let band = BarSliderBands.glyphSize(thickness: thickness)
            #expect(band.lowerBound == Double(KiwiShelf.minContentDepth))
            #expect(band.upperBound >= Double(thickness))
            var shelf = KiwiShelf()
            shelf.glyphSize = CGFloat(band.upperBound)
            #expect(shelf.contentDepth(forDepth: thickness) == thickness)
        }
        let band = BarSliderBands.glyphSize(thickness: 40)
        var shelf = KiwiShelf()
        shelf.glyphSize = CGFloat(band.upperBound) - 1
        #expect(shelf.contentDepth(forDepth: 40) < 40)
        let declared = try declaration(of: "glyphSize", keyword: "func")
        #expect(
            declared.contains(
                "let floor = Double(KiwiShelf.minContentDepth)"
            )
        )
    }

    /// Glyph size sits directly above Font size in the Style
    /// drawer, since an automatic font size follows it (#1713).
    @Test("the glyph size rows sit directly above the font size")
    func glyphSizeSitsAboveFontSize() throws {
        let order = BarsRowOrder.kiwishelfStyle
        let auto = try #require(
            order.firstIndex(of: .kiwishelf(.glyphSizeAuto))
        )
        #expect(order[auto + 1] == .kiwishelf(.glyphSize))
        #expect(order[auto + 2] == .kiwishelf(.fontSizeAuto))
    }

    /// The slider runs to the DRAFT's thickness: the group reads
    /// it once and hands that one value to the band and to the
    /// restore, so a literal or the band's widest thickness in
    /// either place reds here (#1713).
    @Test("the glyph size slider runs to the draft's thickness")
    func glyphSizeReadsTheDraftThickness() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars)
        let sources = try SourceScan.swiftSources(under: root)
        let body = try rowProperty("glyphSizeGroup", in: sources)
        #expect(!body.isEmpty, "glyphSizeGroup moved")
        #expect(
            body.contains("let thickness = shelf.thickness.wrappedValue")
        )
        #expect(
            body.contains(
                "BarSliderBands.glyphSize(thickness: thickness)"
            )
        )
        #expect(body.contains("restore: thickness"))
    }

    /// Which band each Core-clamped bar row reads, keyed by the
    /// suffix of its census model path — a third band joins by
    /// data (#1516).
    private static let bands: [(suffix: String, band: String)] = [
        ("kiwishelf.thickness", "thickness"),
        ("kiwishelf.outerMargin", "margin"),
        ("kiwishelf.innerMargin", "margin"),
        ("kiwishelf.itemGap", "itemGap"),
        ("spaceBarStyle.glyphGap", "glyphGap"),
        ("kiwishelf.highlightWidth", "highlightWidth"),
        ("kiwishelf.glyphSize (auto)", "glyphSize"),
    ]

    /// The body of `var <name>: some View {` in the card sources:
    /// an arm that delegates its row to a property is scanned
    /// there (#1682).
    private func rowProperty(
        _ name: String,
        in sources: [URL]
    ) throws -> String {
        for file in sources {
            let text = try SourceScan.strippedSource(at: file)
            guard let start = text.range(of: "var \(name): some View {")
            else { continue }
            let rest = text[start.upperBound...]
            let end =
                rest.range(of: "\n    }\n")?.lowerBound ?? rest.endIndex
            return String(rest[..<end])
        }
        return ""
    }

    /// The census keys whose model path ends in `suffix` — the
    /// register the consumer count derives from.
    private func keys(withSuffix suffix: String) -> [String] {
        SettingKey.allCases.compactMap { key in
            switch key {
            case .kiwishelf(let k) where k.rawValue.hasSuffix(suffix):
                return String(describing: k)
            case .spaceBar(let k) where k.rawValue.hasSuffix(suffix):
                return String(describing: k)
            default:
                return nil
            }
        }
    }

    @Test("every clamped row's arm takes its one band")
    func everyClampedArmTakesItsBand() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars)
        let sources = try SourceScan.swiftSources(under: root)
        for (suffix, band) in Self.bands {
            let keys = keys(withSuffix: suffix)
            #expect(keys.count == 1, "\(suffix): \(keys)")
            var rendered: [String: Int] = [:]
            for file in sources {
                let text = try SourceScan.strippedSource(at: file)
                for key in keys {
                    var rest = text
                    while let arm = rest.range(of: "case .\(key):") {
                        rest = String(rest[arm.upperBound...])
                        // The arm runs to the next `case` label.
                        let end =
                            rest.range(of: "\n        case ")?
                            .lowerBound
                            ?? rest.range(of: "\n        default")?
                            .lowerBound
                            ?? rest.endIndex
                        // Every slider the arm draws, not the
                        // first: a second one beside the routed
                        // one is the restatement the count exists
                        // to catch (guard-prover, 2026-09-21).
                        var body = String(rest[..<end])
                        let named = body.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        if !body.contains("PtSlider("), !named.isEmpty,
                            named.allSatisfy({ $0.isLetter || $0.isNumber })
                        {
                            body = try rowProperty(named, in: sources)
                        }
                        while let args = SourceScan.callArguments(
                            of: "PtSlider(",
                            in: body
                        ) {
                            rendered[key, default: 0] += 1
                            #expect(
                                args.contains(
                                    "range: BarSliderBands.\(band)"
                                ),
                                "\(file.lastPathComponent) ▸ \(key) restates"
                            )
                            guard let made = body.range(of: "PtSlider(")
                            else { break }
                            body = String(body[made.upperBound...])
                        }
                    }
                }
            }
            for key in keys {
                #expect(
                    rendered[key] == 1,
                    "\(key) draws \(rendered[key] ?? 0) slider(s)"
                )
            }
        }
    }
}
