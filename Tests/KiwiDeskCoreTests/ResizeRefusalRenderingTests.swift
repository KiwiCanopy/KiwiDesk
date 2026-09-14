import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure derivations a refusal's own case answers (#1258):
/// which way the ring bumps, what the pill says, and which
/// window wears the second one.
///
/// They need tests of their own because none of them is
/// observable through the seam the behaviour suites read.
/// `flashDeadEnd` is gated on `privateRuntimeStarted` and hands
/// back nothing, and the pill's text is display-gated — so four
/// `flashDeadEnd` calls a reviewer could once count at four call
/// sites became one derived property that nothing watched
/// (review, 2026-09-05).
///
/// No locale is pinned, deliberately: every assertion here
/// compares rendered sentences to EACH OTHER, which holds in any
/// language — and a locale that collided two of them would be a
/// real defect this suite should catch, not a fixture problem.
/// An assertion swapped to an English literal owes the pin
/// (#740).
@Suite("Resize refusal rendering (#1258)")
@MainActor
struct ResizeRefusalRenderingTests {
    private let window = WindowID(1)
    private let other = WindowID(2)

    @Test("A limit reached bumps; one that does not exist cannot")
    func bumpsOnlyWhereThereIsAWall() {
        // A wall to bounce off exists only where the gesture
        // ran INTO something.
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "y", appBound: false)
                .bumpDirection == .down
        )
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "x", appBound: true)
                .bumpDirection == .right
        )
        #expect(
            ResizeRefusal.ownMaximum(
                window,
                axis: "x",
                atBoundary: true
            ).bumpDirection == .right
        )
        #expect(
            ResizeRefusal.neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y",
                appBound: false
            ).bumpDirection == .down
        )
        // No wall: these three say a limit does not exist.
        #expect(
            ResizeRefusal.noAxisHere(window, axis: "y")
                .bumpDirection == nil
        )
        #expect(
            ResizeRefusal.nothingToDivide(
                window,
                otherAxisDivides: true
            ).bumpDirection == nil
        )
        #expect(
            ResizeRefusal.layoutHasNoResize(window)
                .bumpDirection == nil
        )
    }

    @Test("Every discriminator changes the sentence it rides on")
    func eachDiscriminatorIsRead() {
        // The point of moving these onto the case: a wrong value
        // is a wrong VALUE, which a test can see. Each pair must
        // therefore differ — a renderer that ignored one would
        // make the discriminator decorative.
        #expect(
            ResizeRefusal.ownMaximum(
                window,
                axis: "x",
                atBoundary: true
            ).pillText
                != ResizeRefusal.ownMaximum(
                    window,
                    axis: "x",
                    atBoundary: false
                ).pillText
        )
        #expect(
            ResizeRefusal.nothingToDivide(
                window,
                otherAxisDivides: true
            ).pillText
                != ResizeRefusal.nothingToDivide(
                    window,
                    otherAxisDivides: false
                ).pillText
        )
        // #1261: whose floor it was changes the remedy, so it
        // changes the sentence — on both minimum cases.
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "x", appBound: true)
                .pillText
                != ResizeRefusal.ownMinimum(
                    window,
                    axis: "x",
                    appBound: false
                ).pillText
        )
        #expect(
            ResizeRefusal.neighborMinimum(
                anchor: other,
                focused: window,
                axis: "x",
                appBound: true
            ).pillText
                != ResizeRefusal.neighborMinimum(
                    anchor: other,
                    focused: window,
                    axis: "x",
                    appBound: false
                ).pillText
        )
        #expect(
            ResizeRefusal.noAxisHere(window, axis: "x").pillText
                != ResizeRefusal.noAxisHere(window, axis: "y")
                .pillText
        )
    }

    @Test("No two refusals share a sentence")
    func everyCaseSaysSomethingOfItsOwn() {
        // A sentence duplicated across cases is a case a user
        // cannot tell from another — and the glyph, which is the
        // only other channel, is deliberately shared by three of
        // them (#1260).
        let texts = [
            ResizeRefusal.ownMinimum(window, axis: "y", appBound: false),
            .ownMinimum(window, axis: "y", appBound: true),
            .neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y",
                appBound: false
            ),
            .neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y",
                appBound: true
            ),
            .ownMaximum(window, axis: "y", atBoundary: false),
            .ownMaximum(window, axis: "y", atBoundary: true),
            .noAxisHere(window, axis: "y"),
            .noAxisHere(window, axis: "x"),
            .nothingToDivide(window, otherAxisDivides: false),
            .nothingToDivide(window, otherAxisDivides: true),
            .layoutHasNoResize(window),
            .windowIsFullscreen(window),
        ].map(\.pillText)
        #expect(Set(texts).count == texts.count)
        #expect(texts.allSatisfy { !$0.isEmpty })
    }

    @Test("Each case draws its own sentence, not a neighbour's")
    func sentencesSitOnTheRightCases() {
        // The distinctness test above cannot see a SWAP — two
        // cases exchanging sentences keeps every text unique and
        // ships green (guard-prover, 2026-09-05), while a user
        // reads "this zone divides widths" about a space that
        // divides nothing. Only naming them catches it.
        //
        // This is the one place the English is asserted, so it
        // pins the locale FIRST (#740): `L()` resolves the
        // HOST's language, and a German dev machine would
        // otherwise fail a green tree.
        LocalizationManager.shared.select("en")
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "y", appBound: false)
                .pillText
                == "Minimum window size reached"
        )
        // #1261: a limit the APP enforces names the app, since
        // the remedy is not a KiwiDesk setting — and each of
        // these reads with no press behind it, which the retile
        // pair (#934) requires.
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "y", appBound: true)
                .pillText
                == "This app won't go smaller"
        )
        #expect(
            ResizeRefusal.neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y",
                appBound: false
            ).pillText == "Neighboring window at its minimum size"
        )
        #expect(
            ResizeRefusal.neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y",
                appBound: true
            ).pillText == "Neighboring app won't go smaller"
        )
        // The learned maximum is ALWAYS the app's: no configured
        // global maximum exists, so this branch needs no flag.
        #expect(
            ResizeRefusal.ownMaximum(
                window,
                axis: "y",
                atBoundary: false
            ).pillText == "This app won't go bigger"
        )
        #expect(
            ResizeRefusal.ownMaximum(
                window,
                axis: "y",
                atBoundary: true
            ).pillText == "No room left to grow"
        )
        #expect(
            ResizeRefusal.noAxisHere(window, axis: "y").pillText
                == "This zone divides widths, not heights"
        )
        #expect(
            ResizeRefusal.noAxisHere(window, axis: "x").pillText
                == "This zone divides heights, not widths"
        )
        #expect(
            ResizeRefusal.nothingToDivide(
                window,
                otherAxisDivides: false
            ).pillText == "This zone has nothing to divide"
        )
        #expect(
            ResizeRefusal.nothingToDivide(
                window,
                otherAxisDivides: true
            ).pillText
                == "Nothing to divide here — try the other axis"
        )
        #expect(
            ResizeRefusal.layoutHasNoResize(window).pillText
                == "This layout has no resizing"
        )
        #expect(
            ResizeRefusal.windowIsFullscreen(window).pillText
                == "Full-screen windows can't be resized"
        )
    }

    @Test("Only a paired refusal marks a second window")
    func theSecondPillIsThePairsAlone() {
        // #435: the window that cannot move is marked, and it
        // says what IT hit — its own minimum — while the trier
        // is told why nothing happened.
        let paired = ResizeRefusal.neighborMinimum(
            anchor: other,
            focused: window,
            axis: "y",
            appBound: false
        )
        let second = paired.secondPill
        #expect(second?.window == other)
        #expect(
            second?.text
                == ResizeRefusal.ownMinimum(
                    other,
                    axis: "y",
                    appBound: false
                ).pillText
        )
        #expect(second?.text != paired.pillText)
        // The anchor's mark carries the pair's verdict (#1261):
        // the blocker names its own app where its app bound,
        // never the config-floor sentence.
        let appPaired = ResizeRefusal.neighborMinimum(
            anchor: other,
            focused: window,
            axis: "y",
            appBound: true
        )
        #expect(
            appPaired.secondPill?.text
                == ResizeRefusal.ownMinimum(
                    other,
                    axis: "y",
                    appBound: true
                ).pillText
        )
        #expect(appPaired.secondPill?.text != second?.text)
        // Everything else wears one pill.
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "y", appBound: true)
                .secondPill == nil
        )
        #expect(
            ResizeRefusal.nothingToDivide(
                window,
                otherAxisDivides: false
            ).secondPill == nil
        )
        #expect(
            ResizeRefusal.layoutHasNoResize(window).secondPill
                == nil
        )
        #expect(
            ResizeRefusal.windowIsFullscreen(window).secondPill
                == nil
        )
    }
}
