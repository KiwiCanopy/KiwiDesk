import Foundation
import Testing

/// The Space cue's seams (#2143, #2524): paid from one place, and
/// decided by the one `drawnSpaceTransition` reading inside the
/// payer — so a second switch path cannot show the plate past the
/// user's pick.
@Suite("Space cue seams (#2143, #2524)")
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

    @Test("the stored pick is read once, through the drawn reading")
    func oneReading() throws {
        let files = Dictionary(uniqueKeysWithValues: try Self.sources())
        let cue = try #require(files["SpaceSwitchCue.swift"])
        #expect(cue.contains("guard drawnSpaceTransition == .show,"))
        // Nothing else reads the stored pick to decide a switch:
        // the slide and the cue both take the drawn reading.
        let readers = try Self.sources().filter { _, text in
            text.contains("appWide.spaceTransition")
        }.map(\.0)
        #expect(readers == ["KiwiCore+SpaceSlide.swift"])
    }
}
