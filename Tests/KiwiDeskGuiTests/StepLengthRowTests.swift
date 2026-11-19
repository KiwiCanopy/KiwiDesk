import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Step length row (#3505): a log-scaled slider over Core's
/// clamp floor to 20 mm, snapping onto the default, spoken against
/// the default, and greyed with Long swipes.
@Suite("Step length row (#3505)")
struct StepLengthRowTests {
    /// The low edge is Core's clamp, so every stored value Core
    /// keeps above it is reachable.
    @Test("the low edge is Core's clamp")
    func lowEdgeIsCores() {
        #expect(
            StepLengthScale.range.lowerBound
                == ScrollGestureBase.stepLengthRange.lowerBound
        )
        #expect(
            StepLengthScale.range.upperBound
                <= ScrollGestureBase.stepLengthRange.upperBound
        )
    }

    /// Log-scaled: the geometric mean of the ends sits mid-track,
    /// and a value outside the span pins to the nearer end.
    @Test("the track is log-scaled and pins out-of-range values")
    func logScale() {
        let range = StepLengthScale.range
        #expect(StepLengthScale.position(of: range.lowerBound) == 0)
        #expect(StepLengthScale.position(of: range.upperBound) == 1)
        let mean = (range.lowerBound * range.upperBound).squareRoot()
        #expect(abs(StepLengthScale.position(of: mean) - 0.5) < 1e-9)
        #expect(StepLengthScale.position(of: 40) == 1)
        #expect(StepLengthScale.position(of: 1) == 0)
    }

    /// A position stores the mm it names, to 0.1 mm.
    @Test("a position round-trips to its length")
    func roundTrip() {
        for mm in [3.0, 4.5, 9.0, 14.0, 20.0] {
            let back = StepLengthScale.length(
                at: StepLengthScale.position(of: mm)
            )
            #expect(abs(back - mm) < 0.051)
        }
    }

    /// A value Lua set past the span stays while the knob rests at
    /// that end: "Longer" never shortens 40 mm to 20.
    @Test("a value past the span survives a press at its end")
    func pastTheSpanIsKept() {
        #expect(StepLengthScale.keeps(40, at: 1))
        #expect(!StepLengthScale.keeps(40, at: 0.9))
        #expect(!StepLengthScale.keeps(12, at: 1))
    }

    /// Near the default's tick a drag lands on the default exactly;
    /// past the snap it does not.
    @Test("a drag near the tick snaps onto the default")
    func snapsOntoTheDefault() {
        let tick = StepLengthScale.defaultPosition
        let base = ScrollGestureBase.defaults.stepLength
        #expect(StepLengthScale.length(at: tick + 0.02) == base)
        #expect(StepLengthScale.length(at: tick - 0.02) == base)
        #expect(StepLengthScale.length(at: tick + 0.04) != base)
        #expect(
            StepLengthScale.length(at: tick + StepLengthScale.notch)
                != base
        )
    }

    /// VoiceOver hears where the value sits against the default.
    @Test("the spoken value names its side of the default")
    @MainActor
    func spokenAgainstTheDefault() {
        LocalizationManager.shared.select("en")
        let base = ScrollGestureBase.defaults.stepLength
        #expect(ScrollGestureWords.stepSpoken(base) == "Default")
        #expect(ScrollGestureWords.stepSpoken(base - 1) == "Shorter")
        #expect(ScrollGestureWords.stepSpoken(base + 1) == "Longer")
    }

    /// The row greys on the gate above and writes the stored step
    /// length through the scale, never a value of its own.
    @Test("the row reads the gate and writes through the scale")
    func rowWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let url = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Gestures/"
                + "GestureStepLengthRow.swift"
        )
        let row = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            row.contains(".inertReason(for:.shortcuts(.scrollStepLength))")
        )
        #expect(
            row.contains(".modifier(GreyOut(active:reason!=nil,help:help))")
        )
        #expect(
            row.contains(
                "guard!StepLengthScale.keeps(stored,at:$0)else{return}"
                    + "model.config.scrollGesture.stepLength="
                    + "StepLengthScale.length(at:$0)"
            )
        )
    }

    /// Greyed while Long swipes is off, and with Long swipes' own
    /// reason while that is greyed.
    @Test("it greys with Long swipes")
    func greysWithLongSwipes() {
        let key = SettingKey.shortcuts(.scrollStepLength)
        var config = GuiConfig()
        #expect(ShortcutsGates(config: config).inertReason(for: key) == nil)
        config.scrollGesture.longSwipes = false
        #expect(
            ShortcutsGates(config: config).inertReason(for: key)
                == .longSwipesOff
        )
        config.scrollGesture.longSwipes = true
        config.gesture[GestureKey(.swipe2, GestureSeeds.panKeys)] = .unbound
        #expect(
            ShortcutsGates(config: config).inertReason(for: key)
                == .noPanSwipe
        )
    }
}
