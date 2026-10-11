import Foundation
import Testing

/// The Space cue's seams (#2143): paid from one place, on the
/// slide's own intent, and decided by the one reading the slide
/// also takes — so a stand-down added to one is never missing
/// from the other.
@Suite("Space cue seams (#2143)")
struct SpaceCueSeamTests {
    private static let core = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/KiwiDeskCore")

    private static func sources() throws -> [(String, String)] {
        let walker = FileManager.default.enumerator(
            at: core,
            includingPropertiesForKeys: nil
        )
        var out: [(String, String)] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            out.append(
                (
                    url.lastPathComponent,
                    try String(contentsOf: url, encoding: .utf8)
                )
            )
        }
        #expect(!out.isEmpty)
        return out
    }

    @Test("spaceSwitchRetile is the one payer")
    func onePayer() throws {
        let calls = try Self.sources().flatMap { name, text in
            text.components(separatedBy: "paySpaceCue(on:").dropFirst()
                .map { _ in name }
        }
        #expect(calls == ["KiwiCore+SpaceTransition.swift"])
    }

    @Test("the slide and the cue read the one style")
    func oneReading() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.sources())
        let slide = try #require(files["KiwiCore+SpaceSlide.swift"])
        let cue = try #require(files["SpaceSwitchCue.swift"])
        #expect(
            slide.contains(
                "var spaceSlideStandsDown: Bool { drawnSpaceChange != .slide }"
            )
        )
        #expect(cue.contains("guard drawnSpaceChange == .cue"))
        // Nothing else reads the stored style to decide a switch.
        let readers = try Self.sources().filter { name, text in
            text.contains("animations.spaceChange")
                && name != "KiwiCore+SettingsCommands.swift"
        }.map(\.0)
        #expect(readers == ["KiwiCore+SpaceSlide.swift"])
    }
}
