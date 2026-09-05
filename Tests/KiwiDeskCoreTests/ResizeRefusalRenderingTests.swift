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
            ResizeRefusal.ownMinimum(window, axis: "y")
                .bumpDirection == .down
        )
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "x")
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
                axis: "y"
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
            ResizeRefusal.ownMinimum(window, axis: "y"),
            .neighborMinimum(
                anchor: other,
                focused: window,
                axis: "y"
            ),
            .ownMaximum(window, axis: "y", atBoundary: false),
            .ownMaximum(window, axis: "y", atBoundary: true),
            .noAxisHere(window, axis: "y"),
            .noAxisHere(window, axis: "x"),
            .nothingToDivide(window, otherAxisDivides: false),
            .nothingToDivide(window, otherAxisDivides: true),
            .layoutHasNoResize(window),
        ].map(\.pillText)
        #expect(Set(texts).count == texts.count)
        #expect(texts.allSatisfy { !$0.isEmpty })
    }

    @Test("Only a paired refusal marks a second window")
    func theSecondPillIsThePairsAlone() {
        // #435: the window that cannot move is marked, and it
        // says what IT hit — its own minimum — while the trier
        // is told why nothing happened.
        let paired = ResizeRefusal.neighborMinimum(
            anchor: other,
            focused: window,
            axis: "y"
        )
        let second = paired.secondPill
        #expect(second?.window == other)
        #expect(
            second?.text
                == ResizeRefusal.ownMinimum(other, axis: "y")
                .pillText
        )
        #expect(second?.text != paired.pillText)
        // Everything else wears one pill.
        #expect(
            ResizeRefusal.ownMinimum(window, axis: "y")
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
    }
}
