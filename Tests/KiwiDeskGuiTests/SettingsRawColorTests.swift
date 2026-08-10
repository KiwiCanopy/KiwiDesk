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
    ///
    /// Any boundary-terminated `.hue` token counts, NOT just
    /// call shapes: the first cut matched only
    /// `foregroundStyle(.green)` forms, and two of its own
    /// motivating defects — a switch arm's `case .applied:
    /// .green` and a ternary's `flashing ? .red : …` — were
    /// invisible to it (review 2026-08-10; "a needle that
    /// CANNOT FAIL is worse than none"). `.redacted` and
    /// friends survive via the identifier-boundary check. The
    /// map is the one copy of who may, and an entry whose
    /// grounds have gone reds.
    private let hueExempt: [String: String] = [
        "SettingsDestination.swift":
            "the destination tile hue set (.indigo/.blue/"
            + ".purple beside two RGB literals) — the tile "
            + "retune is an eyeball item of the responsive "
            + "pass, and until it lands these are the shipped "
            + "design",
        "AppBarPreviewStrip+Mock.swift":
            "the mock desktop's app windows carry varied "
            + "native hues on purpose — a PICTURE of "
            + "third-party content, not app chrome",
        "Color+KiwiHex.swift":
            "RGBA tuple member accessors (c.red, c.green) in "
            + "the hex parser — the token scan cannot tell a "
            + "tuple member from a Color hue, and no Color is "
            + "drawn here",
        "ColorField.swift":
            "same RGBA tuple accessors in the swatch's "
            + "conversion plumbing",
    ]

    @Test("no fixed system hue is drawn in the Settings tree")
    func noFixedHues() throws {
        let hues = [
            "green", "blue", "orange", "red", "yellow",
            "purple", "pink", "mint", "teal", "cyan",
            "indigo", "brown",
        ]
        var scanned = 0
        var hits: [String] = []
        var used: Set<String> = []
        for file in try swiftFiles(under: Self.settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            let found = hues.filter {
                containsToken(source, dotted: $0)
            }
            guard !found.isEmpty else { continue }
            if hueExempt[file.lastPathComponent] != nil {
                used.insert(file.lastPathComponent)
            } else {
                hits.append(
                    "\(file.lastPathComponent): "
                        + found.joined(separator: ", ")
                )
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
        #expect(
            used == Set(hueExempt.keys),
            Comment(
                rawValue:
                    "stale hue exemptions: "
                    + Set(hueExempt.keys).subtracting(used)
                    .sorted().joined(separator: ", ")
            )
        )
    }

    /// Whether `.hue` occurs as a complete member token —
    /// boundary-checked on both sides so `.redacted` cannot
    /// match `.red` and `Color.green` still does.
    private func containsToken(
        _ source: String,
        dotted name: String
    ) -> Bool {
        let needle = "." + name
        var rest = Substring(source)
        while let hit = rest.range(of: needle) {
            let after = rest[hit.upperBound...].first
            let boundary =
                after == nil
                || !(after!.isLetter || after!.isNumber
                    || after! == "_")
            if boundary { return true }
            rest = rest[hit.upperBound...]
        }
        return false
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

    // The hierarchical-grey fixed-ground ban lives in
    // `SettingsFixedGroundTests` — split at the §2.1 ceiling.

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
