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

    /// The `static let <name>` declaration in `BarSliderBands`,
    /// through the end of its initializer.
    private func declaration(of name: String) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars)
            .appendingPathComponent("BarSliderBands.swift")
        let text = try SourceScan.strippedSource(at: file)
        let needle = "static let \(name)"
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
        #expect(band.lowerBound == Double(AppBarStyle.minThickness))
        #expect(band.contains(Double(AppBarStyle().thickness)))
        #expect(band.contains(Double(SpaceBarStyle().thickness)))
        let declared = try declaration(of: "thickness")
        #expect(declared.contains("AppBarStyle.minThickness"))
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

    /// The census keys whose model path is a bar style's
    /// thickness — the register the consumer count derives from.
    private var thicknessKeys: [String] {
        SettingKey.allCases.compactMap { key in
            switch key {
            case .appBar(let k)
            where k.rawValue.hasSuffix("Style.thickness"):
                return String(describing: k)
            case .spaceBar(let k)
            where k.rawValue.hasSuffix("Style.thickness"):
                return String(describing: k)
            default:
                return nil
            }
        }
    }

    @Test("every thickness row's arm takes the one band")
    func everyThicknessArmTakesTheBand() throws {
        let keys = thicknessKeys
        #expect(keys.count == 2, "\(keys)")
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars)
        var rendered: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: file)
            for key in keys {
                var rest = text
                while let arm = rest.range(of: "case .\(key):") {
                    rest = String(rest[arm.upperBound...])
                    // The arm runs to the next `case` label.
                    let end =
                        rest.range(of: "\n        case ")?.lowerBound
                        ?? rest.range(of: "\n        default")?
                        .lowerBound
                        ?? rest.endIndex
                    let body = String(rest[..<end])
                    guard
                        let args = SourceScan.callArguments(
                            of: "PtSlider(",
                            in: body
                        )
                    else { continue }
                    rendered[key, default: 0] += 1
                    #expect(
                        args.contains("range: BarSliderBands.thickness"),
                        "\(file.lastPathComponent) ▸ \(key) restates"
                    )
                }
            }
        }
        for key in keys {
            #expect(rendered[key] == 1, "\(key) drawn \(rendered[key] ?? 0)×")
        }
    }
}
