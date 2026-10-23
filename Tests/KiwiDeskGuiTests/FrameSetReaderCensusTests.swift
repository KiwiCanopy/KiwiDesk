import Foundation
import Testing

/// A pass produces two frame sets (#934): the SLOTS
/// (`calculatedFrames`), which a reader CLASSIFIES — a side, a
/// drop target, a neighbour, a cascade order — and the frames the
/// retile ISSUES (`placedFrames`), where a split layout's floor
/// residue sits inward of its slot, which a reader takes when it
/// acts on where a window IS. An inward frame overlaps its
/// neighbour by construction, so a classifier handed the issued
/// set reads a pile; a cue handed the slots draws beside the
/// window. `allowed` is the one copy of who reads which and why:
/// a new reader joins it with its reason, and an entry whose site
/// is gone leaves.
@Suite("Frame-set reader census (#934)")
struct FrameSetReaderCensusTests {
    enum FrameSet: String { case slots, issued }

    /// File → (set, reason), for every production call site of
    /// either accessor outside the engine's own definitions.
    static let allowed: [String: (set: FrameSet, why: String)] = [
        "TilingEngine.swift": (
            .issued, "the retile applies what the pass issues"
        ),
        "KiwiCore+SizeLimitPill.swift": (
            .issued, "a pill draws on the window's frame"
        ),
        "KiwiCore+DeadEndCue.swift": (
            .issued, "the bump rides the window's frame"
        ),
        "KiwiCore+UnsolicitedResize.swift": (
            .issued,
            "off-frame is judged against the frame the window was "
                + "asked to hold"
        ),
        "KiwiCore+FocusRaise.swift": (
            .issued,
            "a scroll target is revealed once the window sits where "
                + "it was asked to"
        ),
        "KiwiCore+HoverFocus.swift": (
            .issued,
            "a hover stands down if a focus would move any window "
                + "from where it was asked to sit (#1869)"
        ),
        "KiwiCore+AppBarVisibility.swift": (
            .issued,
            "an App Bar item dims by where its window sits (#2234)"
        ),
        "KiwiCore+Borders.swift": (
            .slots,
            "membership and fallback geometry; rings draw "
                + "the real frame"
        ),
        "KiwiCore+Drag.swift": (
            .slots, "the drop target is a shown region"
        ),
        "KiwiCore+DragMove.swift": (
            .slots, "the drag classifies shown regions"
        ),
        "KiwiCore+DragCrossing.swift": (
            .slots, "a crossing is between regions"
        ),
        "KiwiCore+MouseResizeEnd.swift": (
            .slots, "the drag's ratio translation classifies sides"
        ),
        "KiwiCore+MouseWarp.swift": (
            .slots,
            "the warp centres on the region, inside every "
                + "issued frame by construction"
        ),
        "KiwiCore+ZOrder.swift": (
            .slots, "the cascade raise order is a region order"
        ),
        "KiwiCore+TrackNavigate.swift": (
            .slots, "navigation is geometric over shown regions"
        ),
        "KiwiCore+SwapCommand.swift": (
            .slots,
            "an id swap's #438 refusal classifies a shown pile (#2509)"
        ),
        "KiwiCore+NavigateCommand.swift": (
            .slots, "navigation is geometric over shown regions"
        ),
        "KiwiCore+FocusEdge.swift": (
            .slots, "the focus wrap's landing is a navigation (#2493)"
        ),
        "KiwiCore+ResizeScrollSlot.swift": (
            .slots, "the press measures the drawn slot"
        ),
        "KiwiCore+RatioWriters.swift": (
            .slots, "`BspSplit.sides` classifies the first split"
        ),
        "KiwiCore+ResizeBsp.swift": (
            .slots, "the focus sign reads the slot's side"
        ),
        "KiwiCore+RunRest.swift": (
            .slots,
            "`shownSlots()`, the slots without a run's hidden windows "
                + "(#2235)"
        ),
    ]

    /// The classifiers that read a scrolled run's hidden windows
    /// as a pile unless they drop them (#2235): each reads the
    /// slots through `shownSlots()` alone, so a site going back
    /// to the raw `calculatedFrames(state:)` reds here — the
    /// register above counts both as `.slots`.
    static let viaShownSlots: Set<String> = [
        "KiwiCore+Drag.swift",
        "KiwiCore+DragMove.swift",
        "KiwiCore+NavigateCommand.swift",
        "KiwiCore+FocusEdge.swift",
        "KiwiCore+TrackNavigate.swift",
        "KiwiCore+SwapCommand.swift",
    ]

    /// The `.slots` readers that may take the raw slots, each with
    /// why a run's hidden window cannot mislead it. With
    /// `viaShownSlots` it partitions the `.slots` side, so a new
    /// slot reader reds until it says which it is.
    static let rawSlotsRuled: [String: String] = [
        "KiwiCore+RunRest.swift": "the `shownSlots()` door itself",
        "KiwiCore+Borders.swift":
            "a ring's fallback is its own window's slot, never a pile",
        "KiwiCore+DragCrossing.swift":
            "a crossing is between screens, never a pile test",
        "KiwiCore+MouseResizeEnd.swift":
            "the dragged window's own side; a hidden one is not dragged",
        "KiwiCore+MouseWarp.swift":
            "the warp centres on the focus, which a run always shows",
        "KiwiCore+ZOrder.swift":
            "a whole-zone pile's cascade; a run takes its own restore",
        "KiwiCore+ResizeScrollSlot.swift": "Scrolling draws no run",
        "KiwiCore+RatioWriters.swift": "bsp draws no run",
        "KiwiCore+ResizeBsp.swift": "bsp draws no run",
    ]

    @Test("Every slots reader says whether a run can mislead it")
    func slotsSideIsPartitioned() {
        let slots = Set(
            Self.allowed.filter { $0.value.set == .slots }.keys
        )
        let ruled = Set(Self.rawSlotsRuled.keys)
        #expect(Self.viaShownSlots.isDisjoint(with: ruled))
        #expect(slots == Self.viaShownSlots.union(ruled))
    }

    @Test("The run-aware classifiers read only the shown slots")
    func classifiersDropHidden() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var found = 0
        for url in try SourceScan.swiftSources(under: root)
        where Self.viaShownSlots.contains(url.lastPathComponent) {
            found += 1
            let text = try SourceScan.strippedSource(at: url)
            let name = url.lastPathComponent
            #expect(text.contains("shownSlots()"), "\(name)")
            #expect(
                SourceScan.allMatches(
                    in: text,
                    pattern: "(calculatedFrames\\(\\s*state)"
                ).isEmpty,
                "\(name) reads the raw slots"
            )
        }
        #expect(found == Self.viaShownSlots.count)
    }

    @Test("Every reader of either frame set is registered on its side")
    func readersAreRegistered() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var seen: [String: FrameSet] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let name = url.lastPathComponent
            let text = try SourceScan.strippedSource(at: url)
            // A call, never the declaration; the argument label
            // may sit on the next line. The issued set has a
            // one-space overload (`of:`, #2234). `shownSlots()` is
            // the slots with a run's hidden windows left out
            // (#2235), so its callers classify slots too.
            let slots = SourceScan.allMatches(
                in: text,
                pattern: "((?<!func )(calculatedFrames\\(\\s*state"
                    + "|shownSlots\\(\\)))"
            ).count
            let issued = SourceScan.allMatches(
                in: text,
                pattern: "((?<!func )placedFrames\\(\\s*(state|of))"
            ).count
            #expect(
                !(slots > 0 && issued > 0),
                "\(name) reads both sets"
            )
            if slots > 0 { seen[name] = .slots }
            if issued > 0 { seen[name] = .issued }
        }
        // A scan that finds no readers is scanning nothing.
        #expect(seen.count >= 10)
        for (name, set) in seen {
            let entry = Self.allowed[name]
            #expect(entry != nil, "\(name) reads \(set) unregistered")
            #expect(entry?.set == set, "\(name) is on the wrong side")
        }
        for name in Self.allowed.keys {
            #expect(seen[name] != nil, "\(name) no longer reads either")
        }
    }
}
