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

    /// The receiver a `.configure(` call site is spelled on — the
    /// identifier ending at the dot.
    private static func receiver(
        _ text: [Character],
        before start: Int
    ) -> String {
        var i = start
        while i > 0, text[i - 1].isLetter || text[i - 1].isNumber {
            i -= 1
        }
        return String(text[i..<start])
    }

    /// A caller holding the front under any name the tree uses
    /// for it: `mouse.scroll`, or a local `gestures`.
    private static let frontNames: Set<String> = ["scroll", "gestures"]

    @Test("only the home configures the front, whatever it passes")
    func onlyTheHomeConfigures() throws {
        var callers: [String] = []
        for (name, text) in try coreFiles() {
            for site in SourceScan.callSites(in: text, for: ".configure")
            where Self.frontNames.contains(
                Self.receiver(text, before: site.start)
            ) {
                callers.append(name)
            }
        }
        #expect(callers == [Self.home])
    }

    /// The resolve's inputs and output are the home's to write:
    /// the consumer reads `resolved`, so a stray write — whole or
    /// to one sub-field — skips both the override and `configure`.
    @Test("the front's stored inputs are written in the home alone")
    func inputsAreTheHomes() throws {
        let fields = ["base", "profileOverride", "resolved"]
        let names = Self.frontNames.sorted().joined(separator: "|")
        var writers: Set<String> = []
        var homeWrites: [String: Int] = [:]
        for (name, text) in try coreFiles() {
            let source = String(text)
            for field in fields {
                let pattern =
                    "\\b(\(names))\\.\(field)(\\.\\w+)*\\s*=(?!=)"
                let regex = try NSRegularExpression(pattern: pattern)
                let hits = regex.numberOfMatches(
                    in: source,
                    range: NSRange(source.startIndex..., in: source)
                )
                guard hits > 0 else { continue }
                writers.insert(name)
                if name == Self.home { homeWrites[field, default: 0] += hits }
            }
        }
        #expect(writers == [Self.home])
        // Each field still has its home write — a floor per field.
        for field in fields {
            #expect(
                homeWrites[field, default: 0] >= 1,
                "the home no longer writes \(field)"
            )
        }
    }
}
