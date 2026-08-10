import Foundation
import Testing

@testable import KiwiDesk

/// The dark pass's raw-colour lens (#678 turn 16), generalising
/// the `PaletteShelfChromeTests` lesson past the four Palette
/// files: a colour that is not a `SettingsTheme` token answers
/// to the SYSTEM's appearance, not the app's, and the classes
/// below are the ones that shipped dark-mode defects.
///
/// What it deliberately does NOT ban: `Color.primary` (inverts
/// with the appearance and is the hover-wash idiom), and the
/// hierarchical greys `.secondary`/`.tertiary` on MODE-VARYING
/// surfaces — those derive from the ambient ink and self-invert;
/// gui.md's "prefer a concrete ink" stays a preference there.
/// On a FIXED-dark ground they are a defect class (near-white in
/// dark mode's ambient, near-black in light's, on chrome that
/// never changes), so the fixed-ground file set bans them
/// outright.
@Suite("Settings raw-colour lens")
struct SettingsRawColorTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static var settingsDir: URL {
        root.appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    // MARK: - Fixed hues

    /// System hues lift in dark while the app's tokens do not —
    /// the recorder's `.green`/`.orange`, the Lua banner's
    /// `.blue` and the recorder flash's `.red` were this class.
    /// Scoped to `foregroundStyle`/`fill`/`tint` call shapes so
    /// prose and identifiers cannot match.
    @Test("no fixed system hue is drawn in the Settings tree")
    func noFixedHues() throws {
        let hues = [
            ".green", ".blue", ".orange", ".red", ".yellow",
            ".purple", ".pink", ".mint", ".teal", ".cyan",
            ".indigo", ".brown",
        ]
        let shapes = [
            ".foregroundStyle(", ".fill(", ".tint(",
        ]
        var scanned = 0
        var hits: [String] = []
        for file in try swiftFiles(under: Self.settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            ).replacingOccurrences(of: " ", with: "")
            scanned += 1
            for shape in shapes {
                for hue in hues
                where source.contains(shape + hue + ")") {
                    hits.append(
                        "\(file.lastPathComponent): "
                            + shape + hue + ")"
                    )
                }
            }
        }
        // A scan that read nothing passes having looked at
        // nothing (#635).
        #expect(scanned > 50)
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    "fixed hues drawn: \(hits.joined(separator: ", "))"
            )
        )
    }

    // MARK: - RGB literals

    /// `Color(red:...)` beside a view is the drift `SettingsTheme`
    /// exists to end. The map is the one copy of who may.
    private let rgbLiteralExempt: [String: String] = [
        "SettingsDestination.swift":
            "the two destination tile tints with no matching "
            + "system hue — the tile retune is an eyeball item "
            + "of the responsive pass, and until it lands these "
            + "are the shipped design"
    ]

    @Test("no RGB literal outside the exempt map")
    func noRGBLiterals() throws {
        var scanned = 0
        var hits: [String] = []
        for file in try swiftFiles(under: Self.settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            ).replacingOccurrences(of: " ", with: "")
            scanned += 1
            guard source.contains("Color(red:") else { continue }
            if rgbLiteralExempt[file.lastPathComponent] == nil {
                hits.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 50)
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    "unexempted Color(red:) in: "
                    + hits.joined(separator: ", ")
            )
        )
        // An exemption for a file that no longer carries the
        // literal is grounds that have gone (#614).
        for (file, _) in rgbLiteralExempt {
            let url = try #require(
                try swiftFiles(under: Self.settingsDir).first {
                    $0.lastPathComponent == file
                }
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            ).replacingOccurrences(of: " ", with: "")
            #expect(
                source.contains("Color(red:"),
                Comment(
                    rawValue:
                        "\(file) exemption is stale — the "
                        + "literal is gone, drop the entry"
                )
            )
        }
    }

    // MARK: - Fixed white/black

    /// White and black that MEAN white and black are legal —
    /// the map names each and why. Everything else on the list
    /// answers to no appearance and shipped invisible in one.
    private let whiteBlackExempt: [String: String] = [
        "ColorField.swift":
            "the Automatic split-dot IS a white/black glyph, "
            + "and the sRGB conversion fallback never renders",
        "IconPicker.swift":
            "a side-by-side preview of the menu bar in EACH "
            + "appearance — the scheme is a parameter, not a "
            + "branch, and both swatches are always drawn",
        "SettingsSlider.swift":
            "the thumb is ruled white in both modes (its "
            + "docstring rejects onAccentKnob); the black rim "
            + "is its only edge in dark",
        "SidebarTile.swift":
            "the search tile glyph on the destination tints — "
            + "retunes with the tiles in the responsive pass's "
            + "eyeball round",
        "SegmentedPicker.swift":
            "retired by the dark pass — entry lives only so a "
            + "white pill returning reds the stale-exemption "
            + "check instead of shipping",
    ]

    @Test("fixed white/black only where it means white/black")
    func whiteBlackScoped() throws {
        var scanned = 0
        var hits: [String] = []
        var used: Set<String> = []
        let needles = [
            "Color.white", "Color.black",
            ".fill(.white)", ".fill(.black)",
            ".foregroundStyle(.white)",
            ".foregroundStyle(.black)",
            // The gradient-stop and nil-coalesce spellings —
            // ColorField's split-dot and conversion fallback.
            // NOT a bare "color:.black": that matches shadow
            // colours, which are a different class — a black
            // shadow is light-mode lift whose dark half the
            // planeRing construction now carries.
            "init(color:.white", "init(color:.black",
            "??.black", "??.white",
        ]
        for file in try swiftFiles(under: Self.settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            ).replacingOccurrences(of: " ", with: "")
            scanned += 1
            let hit = needles.contains { source.contains($0) }
            guard hit else { continue }
            if whiteBlackExempt[file.lastPathComponent] != nil {
                used.insert(file.lastPathComponent)
            } else {
                hits.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 50)
        #expect(
            hits.isEmpty,
            Comment(
                rawValue:
                    "unexempted fixed white/black in: "
                    + hits.joined(separator: ", ")
            )
        )
        // SegmentedPicker's entry documents a retirement — it
        // must NOT match, and the others must all still exist.
        #expect(!used.contains("SegmentedPicker.swift"))
        let live = Set(whiteBlackExempt.keys)
            .subtracting(["SegmentedPicker.swift"])
        #expect(
            used == live,
            Comment(
                rawValue:
                    "stale white/black exemptions: "
                    + live.subtracting(used).sorted()
                    .joined(separator: ", ")
            )
        )
    }

    // MARK: - Hierarchical greys on fixed-dark grounds

    /// Chrome that is dark in BOTH modes: the ambient-derived
    /// greys land near-white or near-black by the WINDOW's
    /// appearance while the ground never moves. The pill's
    /// readout and the board files ban them outright.
    private let fixedGroundFiles = [
        "SettingsFooter.swift",
        "SettingsFooter+Unsaved.swift",
        "SettingsFooter+Slots.swift",
        "HomeCardPlate.swift",
        "HomeCardPlate+Bars.swift",
        "HomeCardPlate+BarStrip.swift",
        "HomeCardPlate+Desk.swift",
        "HomeCardPlate+Legibility.swift",
        "HomeCardPlate+Scene.swift",
        "HomeCardPlate+SpacesTile.swift",
        "HomeCardPlate+Swatches.swift",
        "KeyboardBoard.swift",
        "KeyboardChrome.swift",
    ]

    @Test("no hierarchical grey on a fixed-dark ground")
    func fixedGroundsBanHierarchicalGreys() throws {
        let needles = [
            ".secondary", ".tertiary", ".quaternary",
        ]
        var scanned = 0
        for file in try swiftFiles(under: Self.settingsDir)
        where fixedGroundFiles.contains(file.lastPathComponent) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            for needle in needles {
                #expect(
                    !source.contains(needle),
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) draws "
                            + "\(needle) on fixed-dark chrome"
                    )
                )
            }
        }
        // The file list is hand-kept; a rename must red, not
        // shrink the scan.
        #expect(scanned == fixedGroundFiles.count)
    }

    // MARK: - Enumeration

    private func swiftFiles(under dir: URL) throws -> [URL] {
        var result: [URL] = []
        let walker = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil
        )
        while let next = walker?.nextObject() as? URL {
            if next.pathExtension == "swift" {
                result.append(next)
            }
        }
        return result
    }
}
