import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's side switch draws titles only, a side's chord standing
/// in for its title while ⌘ is held or the pointer is on it, in a
/// width that never moves (#1229 ▸ Tab bar). `@MainActor` for the
/// renderer and the source scan; a few small renders.
@Suite("Segmented picker hints on demand")
@MainActor
struct SegmentedPickerHintsOnDemandTests {
    private let options = [("Windows", 0), ("View", 1)]

    private func width(
        hints: [Int: String],
        shown: Bool
    ) throws -> CGFloat {
        let picker = SegmentedPicker(
            reservesWeight: true,
            hints: hints,
            showsHints: shown,
            selection: .constant(0),
            options: options
        )
        .fixedSize()
        return try #require(ImageRenderer(content: picker).nsImage)
            .size.width
    }

    @Test("showing the chords never changes the switch's width")
    func widthHolds() throws {
        // One chord wider than its title, one narrower.
        let hints = [0: "⌃⌥J", 1: "⌃⌥⌘⇧F12"]
        let rest = try width(hints: hints, shown: false)
        #expect(try width(hints: hints, shown: true) == rest)
    }

    /// The reserve is the wider of title and chord per segment,
    /// never their sum: chords narrower than their titles cost no
    /// width at all.
    @Test("a narrow chord costs the switch nothing")
    func reserveIsTheWider() throws {
        let bare = try width(hints: [:], shown: false)
        #expect(try width(hints: [0: "J", 1: "L"], shown: false) == bare)
        #expect(try width(hints: [1: "⌃⌥⌘⇧F12"], shown: false) > bare)
    }

    @Test("every chord shows under ⌘; one under the pointer")
    func showsOnDemand() {
        typealias Picker = SegmentedPicker<Int>
        let shows = Picker.showsHint(showsAll:pointer:index:)
        #expect(!shows(false, nil, 0))
        #expect(shows(true, nil, 1))
        #expect(shows(false, 1, 1))
        #expect(!shows(false, 1, 0))
    }

    /// The pointer half reaches the label only through the segment's
    /// own hover, gated as the lift is; no fixture can hover.
    @Test("a segment's hover writes the pointer, enabled only")
    func hoverWritesThePointer() throws {
        let source = try SourceScan.segmentedPickerSource(from: #filePath)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                ".onHover{insideinifinside,isEnabled{pointerIndex=index}"
            )
        )
        #expect(source.contains("pointer:pointerIndex,"))
        // ⌘ held reaches the label, not only the picker's input.
        #expect(source.contains("showsAll:showsHints,"))
    }

    /// The swap is a reel, not a fade (#3172): a centred label moved
    /// by its bottom edge clears the reel either way. The chord rises
    /// from below and the title leaves upward (#3240).
    @Test("the title rolls out upward as the chord rises in")
    func swapRolls() {
        let roll = SegmentRoll.offset(hint:shown:reach:)
        #expect(roll(false, false, 20) == 0)
        #expect(roll(false, true, 20) == -20)
        #expect(roll(true, false, 20) == 20)
        #expect(roll(true, true, 20) == 0)
    }

    /// No fixture can sample a running animation; the wiring is the
    /// claim: both labels on the reel, clipped, 0.18 s ease-out, and
    /// an instant swap under Reduce Motion.
    @Test("both labels ride the clipped reel, never a fade")
    func reelWiring() throws {
        let source = try SourceScan.segmentedPickerSource(from: #filePath)
            .split(whereSeparator: \.isWhitespace).joined()
        for hint in [false, true] {
            #expect(
                source.contains(
                    ".modifier(SegmentRoll(hint:\(hint),shown:shown))"
                )
            )
        }
        #expect(
            source.contains(
                ".coordinateSpace(.named(SegmentRoll.reel)).clipped()"
                    + ".animation(reduceMotion?nil:.easeOut(duration:0.18),"
                    + "value:shown)"
            )
        )
        #expect(
            source.contains("reach:proxy.frame(in:.named(Self.reel)).maxY")
        )
        // The reel runs vertically.
        #expect(source.contains("effect.offset(y:Self.offset("))
        #expect(!source.contains(".opacity(shown"))
    }
}
