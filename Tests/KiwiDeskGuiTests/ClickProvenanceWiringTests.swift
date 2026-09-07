import Foundation
import Testing

/// Pins the #687 click-provenance DELIVERY path in
/// `KiwiCore+BootSeams.swift` — the one hunk no behavior test
/// can red on. `RaiseEchoClickTests` and
/// `ClickReachResolutionTests` all inject `stackingOrderProvider`
/// or fabricate `lastLeftClick`, so deleting either wiring line
/// leaves every one of them green while the escape never fires
/// in production and the first-click-eaten bug silently
/// re-ships (architect review, 2026-08-03; the #684-class
/// "helper watched, wiring untested" hole).
///
/// Needles, all against comment-stripped source:
/// 1. `armMachineSeams()` wires `stackingOrderProvider`
///    to
///    `AXHelper.onScreenStackingOrder`.
/// 2. the left-press wiring takes the one `stampLeftClick`
///    (both arms since #1281), and that stamp — in
///    `KiwiCore+ClickProvenance.swift` — resolves `reached`
///    through `clickReachedWindow(at:)` inside the
///    `lastLeftClick` assignment; press-time resolution is the
///    fix's load-bearing choice, so an echo-time refactor must
///    trip this and re-argue.
/// 3. `armMachineSeams()` wires `pointerWarp` to the CoreGraphics
///    pointer move (#689 — the same seam class, one function
///    over).
///
/// Known limits of the scan (shipped, not denied — the #635
/// practice): a wire assigned at boot and nulled later
/// still matches; needle 2 is textual proximity, so a stamp
/// rewritten to `reached: nil` with a dead
/// `clickReachedWindow(at:)` call left within its 200-char
/// window still passes; a wrong-coordinate-space argument
/// matches too. Closing those needs a parser, and the behavior
/// suites cover none of them either — deletion and relocation,
/// the failure modes that shipped #687, are what this guard
/// reds on (guard-prover, 2026-08-03).
///
/// Lives in the GUI test target purely because `SourceScan`
/// does — the `LogSeamWiringTests` trade.
@Suite("Click-provenance wiring (#687)")
struct ClickProvenanceWiringTests {
    private var bootSeams: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/"
                    + "KiwiCore+BootSeams.swift"
            )
    }

    private var clickProvenance: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/"
                    + "KiwiCore+ClickProvenance.swift"
            )
    }

    private func strippedSource(
        _ url: URL? = nil
    ) throws -> String {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: url ?? bootSeams,
                encoding: .utf8
            )
        )
        // Fail-shut on the scan itself: an empty read would
        // pass no needle, but say so rather than red twice
        // with a misleading message.
        try #require(!source.isEmpty)
        return source
    }

    @Test("boot wires the stacking provider")
    func stackingProviderIsWired() throws {
        let source = try strippedSource()
        let pattern =
            #"stackingOrderProvider\s*=\s*\{[\s\S]"#
            + #"{0,120}?AXHelper\.onScreenStackingOrder"#
        let wired =
            source.range(
                of: pattern,
                options: .regularExpression
            ) != nil
        let message =
            "KiwiCore+BootSeams no longer wires "
            + "stackingOrderProvider to AXHelper."
            + "onScreenStackingOrder — every click "
            + "resolves no provenance and #687 re-ships "
            + "with all behavior tests green."
        #expect(wired, Comment(rawValue: message))
    }

    /// The focus-report gate's frontmost fallback (#1322) — same
    /// class: the provenance suite injects its own reading, so
    /// nothing else reds when boot stops wiring it, and the gate
    /// then fails open before the first activation and after
    /// every `stop()`. Both assignments off the ONE closure, and
    /// in that order — the needle pins the order too.
    @Test("boot wires the focus gate's frontmost reading")
    func frontmostReadingIsWired() throws {
        let source = try strippedSource()
        let pattern =
            #"let frontmost[\s\S]{0,160}?"#
            + #"frontmostApplication[\s\S]{0,200}?"#
            + #"frontmostPIDProvider\s*=\s*frontmost[\s\S]{0,200}?"#
            + #"eventLoop\.frontmostPID\s*=\s*frontmost"#
        let wired =
            source.range(
                of: pattern,
                options: .regularExpression
            ) != nil
        let message =
            "KiwiCore+BootSeams no longer wires "
            + "eventLoop.frontmostPID from the same closure "
            + "as frontmostPIDProvider — the #1322 gate fails "
            + "open before the first activation with every "
            + "behavior test green."
        #expect(wired, Comment(rawValue: message))
    }

    /// The `pointerWarp` seam's wiring (#689) — same class as
    /// the needles beside it: every warp test injects the seam,
    /// so deleting the boot assignment leaves the whole
    /// suite green while `pointerWarp?` stays nil and
    /// mouse-follows-focus silently never moves the pointer.
    @Test("boot wires the pointer warp")
    func pointerWarpIsWired() throws {
        let source = try strippedSource()
        let pattern =
            #"pointerWarp\s*=\s*\{[\s\S]"#
            + #"{0,600}?CGWarpMouseCursorPosition"#
        let wired =
            source.range(
                of: pattern,
                options: .regularExpression
            ) != nil
        let message =
            "KiwiCore+BootSeams no longer wires pointerWarp "
            + "to the CoreGraphics pointer move — "
            + "mouse.follows_focus silently never moves the "
            + "pointer while every warp test stays green "
            + "(they all inject the seam)."
        #expect(wired, Comment(rawValue: message))
    }

    @Test("The press stamp resolves reached at press time")
    func pressStampResolvesReached() throws {
        // The boot wiring hands the press to the ONE stamp —
        // the other-app arm here; the own-window arm and the
        // writer count are `OwnPressProvenanceSeamTests`'.
        let boot = try strippedSource()
        let wiredPattern =
            #"onLeftMouseDown\s*=\s*\{[\s\S]{0,120}?"#
            + #"stampLeftClick\("#
        #expect(
            boot.range(
                of: wiredPattern,
                options: .regularExpression
            ) != nil,
            Comment(
                rawValue: "KiwiCore+BootSeams no longer hands "
                    + "the left press to stampLeftClick"
            )
        )
        let source = try strippedSource(clickProvenance)
        let pattern =
            #"lastLeftClick\s*=\s*\([\s\S]{0,200}?"#
            + #"clickReachedWindow\(at:"#
        let resolves =
            source.range(
                of: pattern,
                options: .regularExpression
            ) != nil
        let message =
            "The left-press stamp no longer resolves which "
            + "window the press reached through "
            + "clickReachedWindow(at:) — the raise-echo "
            + "escape then never fires (or a refactor "
            + "moved resolution to echo time, which "
            + "mid-drain restacks can forge; see "
            + "clickReachedWindow's docstring)."
        #expect(resolves, Comment(rawValue: message))
    }
}
