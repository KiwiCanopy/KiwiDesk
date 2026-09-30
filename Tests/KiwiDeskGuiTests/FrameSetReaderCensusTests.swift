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
        "KiwiCore+MonocleFlip.swift": (
            .issued, "the flip plate lies on the window's frame"
        ),
        "KiwiCore+Borders.swift": (
            .slots,
            "membership and fallback geometry; rings draw "
                + "the real frame"
        ),
        "KiwiCore+Drag.swift": (
            .slots, "the drop target is a region"
        ),
        "KiwiCore+DragMove.swift": (
            .slots, "the drag classifies regions"
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
            .slots, "navigation is geometric over regions"
        ),
        "KiwiCore+NavigateCommand.swift": (
            .slots, "navigation is geometric over regions"
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
    ]

    @Test("Every reader of either frame set is registered on its side")
    func readersAreRegistered() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var seen: [String: FrameSet] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let name = url.lastPathComponent
            let text = try SourceScan.strippedSource(at: url)
            // A call, never the declaration; the argument label
            // may sit on the next line.
            let slots = SourceScan.allMatches(
                in: text,
                pattern: "((?<!func )calculatedFrames\\(\\s*state)"
            ).count
            let issued = SourceScan.allMatches(
                in: text,
                pattern: "((?<!func )placedFrames\\(\\s*state)"
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
