import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's Gestures step (#1873 ▸ Ruling 2026-11-15): trackpad
/// Macs only, rows read from the live bindings, the screen row only
/// with two or more screens, at most five rows before ⌃⌥K.
@MainActor
@Suite("Onboarding gestures step")
struct OnboardingGesturesTests {
    private let hyper: ScrollChord = [.control, .option]

    /// The ladder the 2026-11-15 seeds bind, spelled here so the
    /// step's reading is tested apart from what ships.
    private var ladder: [GestureKey: GestureAction] {
        [
            GestureKey(.swipe2, hyper): .family(.focus),
            GestureKey(.swipe3, hyper): .split(
                GestureSplit(
                    axes: [.leftRight: .space],
                    arms: [
                        .up: LuaAction(
                            lua: KiwiHubSide.desktops.lua,
                            kind: .navigation
                        )
                    ]
                )
            ),
            GestureKey(.swipe4, hyper): .family(.display),
            GestureKey(.tap4): .run(
                LuaAction(lua: "kiwivision.toggle()", kind: .navigation)
            ),
        ]
    }

    @Test("the screen row needs a second screen")
    func screenRowNeedsTwo() {
        // The footnote is read as English (tests.md ▸ pin the locale).
        LocalizationManager.shared.select("en")
        let one = OnboardingGestures.families(
            bindings: ladder,
            screens: 1,
            layer: nil
        )
        let two = OnboardingGestures.families(
            bindings: ladder,
            screens: 2,
            layer: nil
        )
        #expect(
            one.map(\.id) == ["focus", "space", "desktops", "kiwivision"]
        )
        #expect(!one.contains { $0.id == "display" })
        #expect(two.contains { $0.id == "display" })
        #expect(
            OnboardingGestures.footnote(two, longSwipes: true)?
                .contains("screens") == true
        )
        // Focus repeats only with long swipes on.
        let off = OnboardingGestures.footnote(one, longSwipes: false)
        #expect(off?.contains("Focus") == false)
    }

    @Test("an unbound gesture is not taught")
    func readsTheBindings() {
        let rows = OnboardingGestures.families(
            bindings: [:],
            screens: 2,
            layer: nil
        )
        #expect(rows.isEmpty)
    }

    @Test("a Mac without a trackpad plans no Gestures step")
    func noTrackpadNoStep() {
        #expect(
            !OnboardingEntry.plannedSteps(from: .spaces, gestures: false)
                .contains(.gestures)
        )
        let planned = OnboardingEntry.plannedSteps(
            from: .spaces,
            gestures: true
        )
        let keys = planned.firstIndex(of: .keys)
        #expect(planned.firstIndex(of: .gestures) == keys.map { $0 + 1 })
    }

    @Test("the model asks the trackpad read when it plans")
    func modelAsks() {
        let model = OnboardingModel()
        model.hasTrackpad = { false }
        let rows = OnboardingGestures.families(
            bindings: ladder,
            screens: 1,
            layer: nil
        )
        model.gestureRows = { rows }
        model.beginPresentation(at: .spaces)
        #expect(!model.plannedSteps.contains(.gestures))
        model.hasTrackpad = { true }
        model.beginPresentation(at: .spaces)
        #expect(model.plannedSteps.contains(.gestures))
    }
}
