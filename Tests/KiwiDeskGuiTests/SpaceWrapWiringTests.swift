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
        #expect(step.contains("warp:warp,step:step)"))
        let switchBody = try Self.squashed(
            "Commands/KiwiCore+SpaceSwitch.swift"
        )
        #expect(switchBody.contains("spaceSlideIntent(to:space,step:step)"))
        let slide = try Self.squashed("Commands/KiwiCore+SpaceSlide.swift")
        #expect(slide.contains("direction:intent.direction("))
    }
}
