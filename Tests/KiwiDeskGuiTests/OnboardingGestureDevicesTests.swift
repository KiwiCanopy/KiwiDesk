import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Gestures step's glyphs and devices (#3427 ▸ Ruling): each cap
/// is the glyph KiwiHub draws for its gesture with a finger count or
/// motion under it, a mouse has rows of its own, and Trackpad | Mouse
/// is offered only where both devices have rows. Main-actor spend:
/// row building over a dozen bindings, no rendering.
@MainActor
@Suite("Onboarding gesture glyphs and devices (#3427)")
struct OnboardingGestureDevicesTests {
    private let hyper: ScrollChord = [.control, .option]

    private func cap(_ family: OnboardingKeyFamily?) -> OnboardingGestureCap? {
        guard case .gesture(_, let glyph, let caption) = family?.chord
        else { return nil }
        return OnboardingGestureCap(glyph: glyph, caption: caption)
    }

    private func mouseRows(
        _ bindings: [GestureKey: GestureAction]
    ) -> [OnboardingKeyFamily] {
        OnboardingGestures.mouseFamilies(bindings: bindings, layer: nil)
    }

    @Test("a trackpad cap is KiwiHub's glyph with its finger count")
    func trackpadCapIsKiwiHubs() {
        LocalizationManager.shared.select("en")
        let swipe3 = GestureKey(.swipe3, hyper)
        let rows = OnboardingGestures.families(
            bindings: [
                GestureKey(.swipe2, hyper): .family(.focus),
                swipe3: .split(
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
                GestureKey(.tap4): .run(
                    LuaAction(lua: "kiwivision.toggle()", kind: .navigation)
                ),
            ],
            screens: 1,
            layer: nil
        )
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let space = ShortcutGestureBadge(
            key: swipe3,
            direction: nil,
            axis: .horizontal
        )
        #expect(cap(byID["space"])?.glyph == space.symbol)
        #expect(cap(byID["space"])?.caption == "3 fingers")
        let focus = ShortcutGestureBadge(
            key: GestureKey(.swipe2, hyper),
            direction: nil
        )
        #expect(cap(byID["focus"])?.glyph == focus.symbol)
        #expect(cap(byID["focus"])?.caption == "2 fingers")
        #expect(cap(byID["kiwivision"])?.caption == "4-finger tap")
        // One way reached draws that way's arrow.
        let up = ShortcutGestureBadge(key: swipe3, direction: .up)
        #expect(cap(byID["desktops"])?.glyph == up.symbol)
        // VoiceOver keeps the whole motion.
        #expect(byID["space"]?.spoken?.contains("left/right") == true)
        #expect(byID["focus"]?.spoken?.contains("left/right") == false)
    }

    @Test("a row's spoken way follows the way its arrows draw")
    func spokenWayFollowsTheBadge() {
        LocalizationManager.shared.select("en")
        let swipe2 = GestureKey(.swipe2, hyper)
        let rows = OnboardingGestures.families(
            bindings: [
                swipe2: .split(GestureSplit(axes: [.leftRight: .focus]))
            ],
            screens: 1,
            layer: nil
        )
        let focus = rows.first { $0.id == "focus" }
        #expect(
            cap(focus)?.glyph
                == ShortcutGestureBadge(
                    key: swipe2,
                    direction: nil,
                    axis: .horizontal
                ).symbol
        )
        #expect(focus?.spoken?.contains("left/right") == true)
    }

    @Test("the seeded mouse rows, in order, each on KiwiHub's glyph")
    func seededMouseRows() {
        LocalizationManager.shared.select("en")
        let rows = mouseRows(GestureSeeds.seeds(on: .standard))
        #expect(rows.map(\.id) == ["focus", "space", "move", "resize"])
        #expect(
            rows.compactMap { cap($0)?.caption }
                == ["scroll", "scroll sideways", "drag", "drag"]
        )
        // #3447: each cap is the glyph KiwiHub draws for its input.
        let inputs: [GestureInput] = [.wheel, .wheelX, .drag, .drag]
        #expect(
            rows.compactMap { cap($0)?.glyph }
                == inputs.map(GestureListWords.symbol)
        )
        guard case .gesture(let move, _, _) = rows[2].chord else {
            Issue.record("the move row draws no gesture cap")
            return
        }
        #expect(move == [.control, .option])
        #expect(rows[0].spoken?.hasSuffix(", scroll") == true)
    }

    @Test("the side buttons are taught only when bound")
    func sideButtonsWhenBound() {
        LocalizationManager.shared.select("en")
        let base: [GestureKey: GestureAction] = [
            GestureKey(.wheel, hyper): .family(.walk)
        ]
        #expect(!mouseRows(base).contains { $0.id == "buttons" })
        var bound = base
        bound[GestureKey(.sideButtons)] = .family(.space)
        let buttons = mouseRows(bound).first { $0.id == "buttons" }
        #expect(buttons?.label == "Switch Spaces")
        #expect(
            cap(buttons)?.glyph == GestureListWords.symbol(.sideButtons)
        )
        #expect(mouseRows([:]).isEmpty)
        // A family the row cannot name is not taught as focus.
        var swap = base
        swap[GestureKey(.sideButtons)] = .family(.swap)
        #expect(!mouseRows(swap).contains { $0.id == "buttons" })
    }

    @Test("a wheel split along its axis reads as its family")
    func splitWheelReads() {
        let rows = mouseRows([
            GestureKey(.wheel, hyper): .split(
                GestureSplit(axes: [.upDown: .walk])
            )
        ])
        #expect(rows.map(\.id) == ["focus"])
    }

    @Test("the mouse footnote names what its rows scroll")
    func mouseFootnote() {
        LocalizationManager.shared.select("en")
        let all = mouseRows(GestureSeeds.seeds(on: .standard))
        #expect(
            OnboardingGestures.mouseFootnote(all)
                == "Focus and Spaces step as far as you scroll."
        )
        let dragOnly = all.filter { $0.id == "move" }
        #expect(OnboardingGestures.mouseFootnote(dragOnly) == nil)
    }

    private func model(
        trackpad: Bool,
        trackpadRows: Bool,
        mouseRows: Bool
    ) -> OnboardingModel {
        let row = OnboardingKeyFamily(
            id: "focus",
            label: "Move focus",
            chord: .shared([], keys: "")
        )
        let model = OnboardingModel()
        model.hasTrackpad = { trackpad }
        model.gestureRows = { trackpadRows ? [row] : [] }
        model.mouseGestureRows = { mouseRows ? [row] : [] }
        model.beginPresentation(at: .spaces)
        return model
    }

    @Test("Trackpad | Mouse only where both have rows")
    func devicePlan() {
        let both = model(trackpad: true, trackpadRows: true, mouseRows: true)
        #expect(both.offersGestureDevices)
        #expect(both.gestureDevice == .trackpad)
        #expect(both.plannedSteps.contains(.gestures))

        let noPad = model(trackpad: false, trackpadRows: true, mouseRows: true)
        #expect(!noPad.offersGestureDevices)
        #expect(noPad.gestureDevice == .mouse)
        #expect(noPad.plannedSteps.contains(.gestures))

        let padOnly = model(
            trackpad: true,
            trackpadRows: true,
            mouseRows: false
        )
        #expect(!padOnly.offersGestureDevices)
        #expect(padOnly.gestureDevice == .trackpad)

        let none = model(trackpad: true, trackpadRows: false, mouseRows: false)
        #expect(!none.plannedSteps.contains(.gestures))

        both.gestureDevice = .mouse
        #expect(both.gestureFamilies.map(\.id) == ["focus"])
    }
}
