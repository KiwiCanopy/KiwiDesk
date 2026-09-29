import Foundation
import Testing

/// **The scroll tap's settings resolve in ONE home** (#1656,
/// input-and-animation.md): `KiwiCore.applyScrollGestures` lays
/// the live profile's override over the global base and is the
/// only caller of `ScrollGestures.configure`. Held by the VALUE
/// the door takes rather than by the door's name, which a bare
/// `configure(` shares with every bar view: the only production
/// `ScrollGestureSettings` is built by `tapSettings`, so a second
/// caller has to read `tapSettings` or build one itself.
@Suite("Scroll gesture configure seam (#1656)")
struct ScrollGestureConfigureSeamTests {
    /// The resolve home.
    private static let home = "KiwiCore+ScrollGestureSettings.swift"

    /// Files that may construct a `ScrollGestureSettings`, each
    /// with its reason — the one copy of who may.
    private static let builders: [String: String] = [
        "ScrollGestures.swift":
            "declares the front's empty value before any configure",
        "ScrollGestureConfig.swift":
            "`tapSettings`, the one conversion from the stored base",
    ]

    private static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private func coreFiles() throws -> [(name: String, text: [Character])] {
        try SourceScan.swiftSources(under: Self.coreRoot).map {
            (
                $0.lastPathComponent,
                Array(try SourceScan.strippedSource(at: $0))
            )
        }
    }

    @Test("tapSettings is read in the resolve home alone")
    func tapSettingsIsReadInTheHomeAlone() throws {
        var readers: [String] = []
        var scanned = 0
        for (name, text) in try coreFiles() {
            scanned += 1
            guard SourceScan.mentions(".tapSettings", in: text)
            else { continue }
            readers.append(name)
        }
        #expect(scanned > 100)
        #expect(readers == [Self.home])
    }

    @Test("a ScrollGestureSettings is built only where ruled")
    func settingsAreBuiltOnlyWhereRuled() throws {
        var built: Set<String> = []
        for (name, text) in try coreFiles()
        where !SourceScan.callSites(
            in: text,
            for: "ScrollGestureSettings"
        ).isEmpty {
            built.insert(name)
        }
        #expect(built == Set(Self.builders.keys))
    }

    @Test("the configure door is handed the resolved value once")
    func doorHasOneCaller() throws {
        var calls: [String] = []
        for (name, text) in try coreFiles() {
            for site in SourceScan.callSites(in: text, for: ".configure") {
                guard var cursor = site.paren,
                    let argument = SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    ),
                    argument.contains("tapSettings")
                else { continue }
                calls.append(name)
            }
        }
        #expect(calls == [Self.home])
    }
}
