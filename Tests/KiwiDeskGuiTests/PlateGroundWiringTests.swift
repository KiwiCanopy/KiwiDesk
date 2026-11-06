import Foundation
import Testing

@testable import KiwiDesk

/// Every desk picture but Home's cards, which pass `alwaysDark`
/// (#3040), draws the plate its look earned (#2859):
/// each in-scope surface reads the resolved paint through
/// `deskPlate`/`platePaint` or the palette they write, a plate
/// view with no writer takes `SchematicPalette.unresolved`, and
/// three sets close it: only the resolver names the dark plate
/// token; only the resolver, `LookPlate` (#1740) and KiwiHub's
/// `JumpLayoutTile` write the palette environment; and only
/// `appearanceWriters` force an appearance anywhere in the trees.
@Suite("Plate ground wiring")
struct PlateGroundWiringTests {
    /// Surface file → the squashed consult it must carry.
    private let surfaces: [String: String] = [
        "HomeCardPlate.swift":
            ".deskPlate(settings,in:Rectangle(),alwaysDark:true)",
        "SimpleSpacePicture.swift": ".deskPlate(settings,in:shape)",
        "BarsPanelPreview.swift":
            ".deskPlate(settings,in:RoundedRectangle("
            + "cornerRadius:SettingsTheme.panelPlateRadius))",
        "PaletteScenePanel.swift":
            ".deskPlate(settings,in:RoundedRectangle("
            + "cornerRadius:SettingsTheme.panelPlateRadius))",
        "KeyboardPreviewPanel.swift": ".platePaint(model.config.settings)",
        "KeyboardBoard.swift": ".fill((palette??.unresolved).base)",
        "GesturesDrawer.swift": ".platePaint(settings)",
        "GestureEntry.swift": ".background((palette??.unresolved).base)",
        "KiwiVisionPanelPreview.swift":
            ".platePaint(model.config.settings)",
        "KiwiVisionScene.swift": "resolved??.unresolved",
        "OnboardingSpaceRow.swift": ".deskPlate(settings,",
        "OnboardingView+Closing.swift": ".deskPlate(model.tilingSettings(),",
        "LayoutStrip.swift": ".deskPlate(model.config.settings,",
        "LayoutPreviewPanel.swift":
            ".deskPlate(model.config.settings,in:RoundedRectangle("
            + "cornerRadius:SettingsTheme.panelPlateRadius))",
        "SpacesPanelPreview.swift":
            ".deskPlate(settings,in:RoundedRectangle("
            + "cornerRadius:SettingsTheme.panelPlateRadius))",
    ]

    /// The one file that names the dark plate token.
    private let resolver = "HomeCardPlate+Ground.swift"

    /// Each scanned file, comments stripped and whitespace squashed;
    /// `spaced` keeps the whitespace, which a declaration read needs.
    private func sources(spaced: Bool = false) throws -> [(String, String)] {
        try ChromeScanRoots.sources(from: #filePath).map {
            let source = SourceScan.stripComments(
                try String(contentsOf: $0, encoding: .utf8)
            )
            return (
                $0.lastPathComponent,
                spaced
                    ? source
                    : source.split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    @Test("every surface reads the resolved paint")
    func surfacesReadThePaint() throws {
        let all = Dictionary(
            try sources(),
            uniquingKeysWith: { first, _ in first }
        )
        for (file, needle) in surfaces {
            let source = try #require(
                all[file],
                Comment(rawValue: "\(file) not found")
            )
            #expect(
                source.contains(needle),
                Comment(rawValue: "\(file) lost its plate paint")
            )
            #expect(
                !source.contains("SettingsTheme.previewPlate"),
                Comment(rawValue: "\(file) names the dark plate")
            )
            // The verdict reads the window's appearance; a picture
            // forcing its own would pick the plate for it. The
            // KiwiVision scene's windows take the appearance the
            // mode will show, below the writer, and are the one
            // spelling allowed, in that file alone (its row in
            // `appearanceWriters` counts the same write).
            let forced =
                file == "KiwiVisionScene.swift"
                ? source.replacingOccurrences(
                    of: ".environment(\\.colorScheme,"
                        + "darkWindows?.dark:.light)",
                    with: ""
                )
                : source
            #expect(
                !forced.contains("\\.colorScheme")
                    && !forced.contains("EnvironmentValues.colorScheme")
                    && !forced.contains("preferredColorScheme("),
                Comment(rawValue: "\(file) forces an appearance")
            )
        }
        // One fallback: a plate view with no writer reads the
        // resolver's unresolved paint, never a value it picks — a
        // member of another palette (`palette?.x ?? y`) or a palette
        // of its own (`palette ?? y`). The schematic kit's own
        // fallbacks are its brand mode, drawn with no plate at all.
        // Trade: a palette handed in as an init parameter or stored
        // property under another name is not a reader here.
        let reader = try Regex(
            "@Environment\\(\\\\(?:EnvironmentValues)?\\.schematicPalette\\)"
                + "\\s*(?:(?:private|fileprivate|internal|public)\\s+)?"
                + "var\\s+(\\w+)"
        )
        let spaced = Dictionary(
            try sources(spaced: true),
            uniquingKeysWith: { first, _ in first }
        )
        func brandMode(_ file: String) -> Bool {
            file.hasPrefix("LayoutSchematic")
                || file.hasSuffix("Schematic.swift")
                || file == "SchematicCardColors.swift"
        }
        var scanned = 0
        // The reader is found by its declaration, whatever it is
        // named (#2871); a non-palette name reads as itself.
        var named = 0
        for (file, source) in all where !brandMode(file) {
            scanned += 1
            let names = (spaced[file] ?? "").matches(of: reader).compactMap {
                $0.output[1].substring.map(String.init)
            }
            named += names.filter { $0 == "palette" }.count
            for name in Set(names + ["palette"]) {
                let own = "(?:^|[^\\w.])" + name
                let picked = try Regex(
                    own + "\\?\\.\\w+\\?\\?|" + own
                        + "\\?\\?(?!\\.unresolved)"
                )
                guard source.contains(picked) else { continue }
                Issue.record(
                    Comment(rawValue: "\(file) picks its own fallback")
                )
            }
        }
        #expect(scanned > 50)
        #expect(named > 20)
    }

    @Test("only Home's cards pass alwaysDark")
    func oneDarkHost() throws {
        let hosts = try sources().filter {
            $0.1.contains("alwaysDark:true")
        }
        #expect(hosts.map(\.0) == ["HomeCardPlate.swift"])
    }

    @Test("only the resolver names the dark plate or writes paint")
    func oneResolver() throws {
        let writers: Set<String> = [
            resolver, "LookPlate.swift", "JumpLayoutTile.swift",
        ]
        var named: Set<String> = []
        var wrote: Set<String> = []
        for (file, source) in try sources() {
            if source.contains("SettingsTheme.previewPlate") {
                named.insert(file)
            }
            // Any mention that is not an `@Environment` read is a
            // write, whatever the modifier spelling it.
            let mentions =
                source.occurrences(of: "\\.schematicPalette")
                + source.occurrences(
                    of: "\\EnvironmentValues.schematicPalette"
                )
            let reads =
                source.occurrences(of: "@Environment(\\.schematicPalette)")
                + source.occurrences(
                    of: "@Environment(\\EnvironmentValues.schematicPalette)"
                )
            if mentions > reads { wrote.insert(file) }
        }
        #expect(named == [resolver])
        #expect(wrote == writers)
    }

    /// A forced appearance anywhere in the scanned trees, a helper
    /// a surface draws included, picks the plate for the picture
    /// (#2871). File → its writes, each with its reason. A write is
    /// any mention of the `colorScheme` key that is not an
    /// `@Environment` read, a `preferredColorScheme(` or
    /// `.colorScheme(` modifier, or an AppKit appearance set
    /// (`NSApp.appearance =`, `.appearance = NSAppearance`). Trade:
    /// an appearance set through any other AppKit spelling is not
    /// seen.
    private let appearanceWriters: [String: Int] = [
        // The KiwiVision scene's windows, below the plate writer.
        "KiwiVisionScene.swift": 1,
        // Forces only under a ruled tint (`panelGlassChrome`, #2569),
        // whose surfaces paint their own palette and draw no plate.
        "GlassChrome.swift": 1,
        // The user's app-wide appearance, which the verdict follows.
        "AppearanceChoice+Scheme.swift": 1,
    ]

    @Test("only the ruled files force an appearance")
    func appearanceWritesAreRuled() throws {
        let key = try Regex(
            "\\\\(?:EnvironmentValues)?\\.colorScheme(?!\\w)"
        )
        var found: [String: Int] = [:]
        for (file, source) in try sources() {
            let mentions = source.matches(of: key).count
            let reads = [
                "@Environment(\\.colorScheme)",
                "@Environment(\\EnvironmentValues.colorScheme)",
            ].reduce(0) { $0 + source.occurrences(of: $1) }
            let modifiers = [
                "preferredColorScheme(", ".colorScheme(",
                "NSApp.appearance=", ".appearance=NSAppearance",
            ].reduce(0) { $0 + source.occurrences(of: $1) }
            let writes = mentions - reads + modifiers
            if writes > 0 { found[file] = writes }
        }
        #expect(found == appearanceWriters)
    }
}
