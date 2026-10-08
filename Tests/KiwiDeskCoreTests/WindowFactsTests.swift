import AppKit
import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// Detection over `WindowFacts` (#1883) keeps the costs the live
/// paths had: the title — a round trip on a live window — is asked
/// only where structure tiles and nothing forces the float. The
/// corpus replays dumps whose title costs nothing, so it cannot
/// see a title asked too early.
@Suite("Window facts (#1883)")
struct WindowFactsTests {
    private static func facts(
        subrole: String,
        layer: Int? = 0,
        asked: @escaping () -> Void
    ) -> WindowFacts {
        WindowFacts(
            role: kAXWindowRole,
            subrole: subrole,
            layer: layer
        ) {
            asked()
            return "Title"
        }
    }

    @Test("a panel floats without its title being read")
    func panelSkipsTheTitle() {
        var asked = false
        let reason = FloatDetection.autoFloatReason(
            Self.facts(subrole: kAXDialogSubrole) { asked = true },
            bundleID: "com.example.app",
            rules: FloatRules(["com.example.app"])
        )
        #expect(reason == .panel)
        #expect(!asked)
    }

    @Test("a standard window reads its title for the rules")
    func standardReadsTheTitle() {
        var asked = false
        let reason = FloatDetection.autoFloatReason(
            Self.facts(subrole: kAXStandardWindowSubrole) {
                asked = true
            },
            bundleID: "com.example.app",
            rules: FloatRules(["com.example.app:Title"])
        )
        #expect(reason == .rule)
        #expect(asked)
    }

    @Test("a raised layer floats a standard window")
    func raisedLayerFloats() {
        let reason = FloatDetection.autoFloatReason(
            Self.facts(subrole: kAXStandardWindowSubrole, layer: 3) {},
            bundleID: nil,
            rules: FloatRules()
        )
        #expect(reason == .panel)
    }

    @Test("a forced float asks detection nothing")
    func forcedSkipsDetection() {
        var asked = false
        let verdict = EventLoop.composeVerdict(
            .facts(
                Self.facts(subrole: kAXStandardWindowSubrole) {
                    asked = true
                }
            ),
            pid: 1,
            activationPolicy: .accessory,
            tilesAsOwnWindow: false,
            bundleID: "com.example.app",
            rules: FloatRules(["com.example.app:Title"])
        )
        #expect(verdict == .floats(.accessoryApp))
        #expect(!asked)
    }

    @Test("an unforced verdict is detection's")
    func unforcedIsDetection() {
        let verdict = EventLoop.composeVerdict(
            .facts(Self.facts(subrole: kAXStandardWindowSubrole) {}),
            pid: 1,
            activationPolicy: .regular,
            tilesAsOwnWindow: false,
            bundleID: nil,
            rules: FloatRules()
        )
        #expect(verdict == .tiles)
        #expect(
            EventLoop.composeVerdict(
                .read(.rule),
                pid: 1,
                activationPolicy: .regular,
                tilesAsOwnWindow: false,
                bundleID: nil,
                rules: FloatRules()
            ) == .floats(.rule)
        )
    }
}
