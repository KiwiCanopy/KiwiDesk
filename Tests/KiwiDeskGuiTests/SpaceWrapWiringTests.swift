import Foundation
import Testing

/// The Space step's key reaches the slide (#2592): `stepSpace` hands
/// its step to the switch, the switch to the slide's intent, and the
/// slide's press reads the intent's direction. No headless fixture
/// presses a slide, so the three hand-offs are needled on their use
/// sites; `SpaceWrapTests` holds the direction itself.
@Suite("Space wrap slide wiring (#2592)")
struct SpaceWrapWiringTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private static func squashed(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: core.appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }

    @Test("the step is handed from the key to the slide")
    func stepReachesTheSlide() throws {
        let step = try Self.squashed("App/KiwiCore+ScrollSpaceStep.swift")
        // Blind to a shadowed `step`, as any needle is; the
        // behaviour is `SpaceWrapTests`'.
        #expect(
            step.contains(
                "switchSpace(to:order[next],warp:warp,step:step,"
                    + "scrolled:scrolled)"
            )
        )
        let switchBody = try Self.squashed(
            "Commands/KiwiCore+SpaceSwitch.swift"
        )
        #expect(
            switchBody.contains(
                "spaceSlideIntent(to:space,step:step,scrolled:scrolled)"
            )
        )
        let slide = try Self.squashed("Commands/KiwiCore+SpaceSlide.swift")
        #expect(slide.contains("direction:intent.direction("))
    }

    /// Only the gesture says it scrolled, and the argument is
    /// required so a door through `stepSpace` cannot leave it out
    /// (#2971). The scan sees the spelling `scrolled: true` alone; a
    /// value computed elsewhere is review's.
    /// `SpaceSlideSwitchTests+Scroll` holds the behaviour.
    @Test("the gesture alone reaches the intent as scrolled")
    func scrolledReachesTheIntent() throws {
        let step = try Self.squashed("App/KiwiCore+ScrollSpaceStep.swift")
        #expect(step.contains("warp:false,scrolled:true)"))
        #expect(step.contains("warp:Bool,scrolled:Bool)->Bool"))
        let keys = try Self.squashed("App/KiwiCore+SpaceHistory.swift")
        #expect(keys.contains("warp:true,scrolled:false)"))
        var saying: [String] = []
        let walker = FileManager.default.enumerator(
            at: Self.core,
            includingPropertiesForKeys: nil
        )
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
            if text.contains("scrolled:true") {
                saying.append(url.lastPathComponent)
            }
        }
        #expect(saying == ["KiwiCore+ScrollSpaceStep.swift"])
    }
}
