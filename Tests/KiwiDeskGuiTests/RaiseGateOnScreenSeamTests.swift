import Foundation
import Testing

/// The raise gate's on-screen read asks SkyLight one window at a
/// time before the public list (#2634), whose read waits on this
/// process's pending window updates while holding the WindowServer
/// connection lock (#2531); why it takes two reads is
/// `SkyLight+WindowVisibility.swift`'s docstring.
@Suite("Raise gate on-screen read seam (#2634)")
struct RaiseGateOnScreenSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private static func body(
        _ declaration: String,
        in file: String
    ) throws -> String {
        let text = try SourceScan.strippedSource(
            at: core.appendingPathComponent(file)
        )
        return String(
            try #require(
                SourceScan.declarationBody(after: declaration, in: text),
                "\(declaration) is gone"
            )
        )
    }

    /// Needled on the returning statement, so an answer read and
    /// dropped reds; trades a false red on an equivalent rewrite.
    @Test("isOnScreen returns SkyLight's answer before the public list")
    func skyLightAnswersFirst() throws {
        let body = try Self.body(
            "static func isOnScreen(",
            in: "AX/FloatDetection.swift"
        ).filter { !$0.isWhitespace }
        let sky = try #require(
            body.range(
                of: "ifletdrawn=SkyLight.windowOnScreen("
                    + "CGWindowID(id.raw)){returndrawn}"
            )
        )
        let list = try #require(body.range(of: "WindowListRead.copy("))
        #expect(sky.upperBound <= list.lowerBound)
    }

    /// The composite's truth table is `WindowVisibilityReadTests`';
    /// this holds that the live read is that call and nothing else,
    /// so a fallback wrapped around it reds. Trades a false red on
    /// any reformatting beyond whitespace.
    @Test("windowOnScreen hands the composite both reads")
    func compositeTakesBothReads() throws {
        let body = try Self.body(
            "static func windowOnScreen(",
            in: "OS/SkyLight+WindowVisibility.swift"
        ).filter { !$0.isWhitespace }
        let statement =
            body.hasPrefix("{") && body.hasSuffix("}")
            ? String(body.dropFirst().dropLast()) : body
        #expect(
            statement
                == "onScreen(orderedIn:windowOrderedIn(wid),"
                + "visible:{windowVisible(wid)})"
        )
    }

    /// The visible row judges the composite the gate reads, not the
    /// bare symbol, which reads true for our own window either way.
    @Test("the visible self_test row judges the composite")
    func selfTestJudgesTheComposite() throws {
        let body = try Self.body(
            ".read(windowIsVisibleSymbol.resolution",
            in: "OS/SkyLight+SelfTest.swift"
        ).filter { !$0.isWhitespace }
        #expect(body.contains("own.flatMap{windowOnScreen($0.id)}"))
    }
}
