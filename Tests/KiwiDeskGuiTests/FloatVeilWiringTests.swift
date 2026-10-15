import Foundation
import Testing

@testable import KiwiDesk

/// The wiring of KiwiVision's float veils (#2103 ruling 3) that no
/// behavioural fixture reaches: every frame site that feeds the
/// mark feeds the veil, the animation seams are wired, and the
/// float raise asks the one `floatsAboveFocus` the veils read.
@Suite("Float veil wiring")
struct FloatVeilWiringTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private func counts(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let count = text.occurrences(of: needle)
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    /// A frame that moves a mark moves the veil: the tick, the AX
    /// move echo and the AX resize echo.
    @Test("every mark frame site feeds the veil")
    func everyFrameSiteFeedsTheVeil() throws {
        let marks = try counts(of: "stickyMarks.follow(")
        #expect(marks.count >= 3, "found \(marks)")
        #expect(try counts(of: "floatDims.follow(") == marks)
    }

    @Test("the veil takes the ring's animation seams")
    func animationSeamsAreWired() throws {
        let bootstrap = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Bootstrap.swift"
            )
        )
        #expect(
            bootstrap.occurrences(
                of: "floatDims.isAnimating = animationDriven"
            ) == 1
        )
        #expect(
            bootstrap.occurrences(
                of: "floatDims.commandedFrame = commandedInstant"
            ) == 1
        )
    }

    /// The raise and the veils read one set, so a veil never misses
    /// a float the raise lifted nor veils one the plate covers.
    @Test("the float raise asks the one floatsAboveFocus")
    func raiseReadsTheSharedSet() throws {
        let raise = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Commands/KiwiCore+ZOrderFloats.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func raiseFloatsAbove(",
                in: raise
            )
        )
        #expect(body.occurrences(of: "floatsAboveFocus(of: id)") == 1)
        #expect(!body.contains("floatLayerTargets("))
        // The composition has one home.
        let targets = try counts(of: "floatLayerTargets()")
        let composed = try counts(of: "isEffectiveFloatOnActiveSpace(")
            .keys.filter { targets[$0] != nil }
        #expect(composed == ["KiwiCore+VisionFloats.swift"])
    }
}
