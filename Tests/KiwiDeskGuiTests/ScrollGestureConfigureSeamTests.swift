import Foundation
import Testing

/// **The scroll tap's settings resolve in ONE home** (#1656,
/// input-and-animation.md): `KiwiCore.applyScrollGestures` lays
/// the live profile's override over the global base and hands the
/// result to the front's one door, `ScrollGestures.adoptResolution`, which
/// writes the resolve's inputs and output and configures the tap.
/// The compiler keeps other writers off those inputs
/// (`private(set)`); these clauses hold the rest of the shape.
@Suite("Scroll gesture configure seam (#1656)")
struct ScrollGestureConfigureSeamTests {
    /// The resolve home, and the front that owns the door.
    private static let home = "KiwiCore+ScrollGestureSettings.swift"
    private static let front = "ScrollGestures.swift"

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

    @Test("tapSettings is read by the front's door alone")
    func tapSettingsIsReadByTheDoor() throws {
        var readers: [String] = []
        var scanned = 0
        for (name, text) in try coreFiles() {
            scanned += 1
            guard SourceScan.mentions(".tapSettings", in: text)
            else { continue }
            readers.append(name)
        }
        #expect(scanned > 100)
        #expect(readers == [Self.front])
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

    @Test("the resolve home is the door's one caller")
    func doorHasOneCaller() throws {
        var calls: [String] = []
        for (name, text) in try coreFiles() {
            for _ in SourceScan.callSites(in: text, for: ".adoptResolution") {
                calls.append(name)
            }
        }
        #expect(calls == [Self.home])
    }

    /// The door is only a door while the inputs behind it cannot
    /// be written from outside the front.
    @Test("the front's stored inputs are private(set)")
    func inputsAreSealed() throws {
        let source = try String(
            contentsOf: Self.coreRoot
                .appendingPathComponent("Events/\(Self.front)"),
            encoding: .utf8
        )
        for field in ["base", "profileOverride", "resolved"] {
            #expect(
                source.contains("private(set) var \(field)"),
                "\(field) is writable from outside the front"
            )
        }
    }

    /// `configure` stays reachable for the front's own tests, so a
    /// Core caller spelling it on the front bypasses the resolve.
    @Test("nothing in Core configures the front but the door")
    func noOtherConfigure() throws {
        var callers: [String] = []
        for (name, text) in try coreFiles() where name != Self.front {
            for site in SourceScan.callSites(in: text, for: ".configure")
            where ["scroll", "gestures"].contains(
                Self.receiver(text, before: site.start)
            ) {
                callers.append(name)
            }
        }
        #expect(callers.isEmpty)
    }

    /// The receiver a call site is spelled on — the identifier
    /// ending at the dot.
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
}
