import Foundation
import Testing

/// The live mouse-button read stays behind its seam
/// (#1103/#1199) — the same defect class as tests seizing the
/// real global hotkey chords (#565), one step removed: no
/// initializer touches the OS here, the touch is a production
/// DEFAULT reading live host state on every decision.
///
/// Three Core sites consulted `NSEvent.pressedMouseButtons`
/// directly — the mouse-follows-focus gate, `isResizeGesture`
/// and the drag pipeline's press check — so a developer using
/// their Mac while `swift test` ran changed the verdict of
/// whichever test happened to be running. They now read
/// `MouseTracker.pressedButtons`, which `makeTestCore` pins;
/// `.claude/rules/tests.md` carries the measurements.
///
/// A sibling of `MachineTouchTests` rather than a needle inside
/// it: that file is at the §2.1 ceiling, and this is the same
/// split `StatusItemSeamGuardTests` already carries. It is also
/// the one register of who may read that mask — the Settings
/// census in `ArrivalRingTests` routes focusable controls
/// through `ClickBornFocus` and defers the home question here.
///
/// Stated residue, both of it. The needle is ONE spelling of the
/// host read: a second reading of the same fact through another
/// API (`CGEventSource.buttonState`) is invisible to it — widen
/// the matcher before excusing a site that takes one. And a
/// census answers WHERE the read lives, never what reads it, so
/// a `pressedButtons` default gutted to a constant beside a read
/// left elsewhere in the file passes; no behavioural test can
/// close that, since the live default answers whatever the host
/// does (guard-prover, 2026-09-06).
@Suite("The live mouse-button read stays behind its seam")
struct MouseButtonSeamGuardTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// The two homes, one per tree: Core's injected seam, and
    /// the GUI's click-born-focus reading, which `ArrivalRingTests`
    /// separately holds every focusable Settings control to.
    private static let allowed = [
        "ClickBornFocus.swift",
        "MouseTracker.swift",
    ]

    /// The pointer read's homes (#1532, the same class one read
    /// over): the drag pipeline's cursor seam (#1103), the
    /// reveal-strip seam beside `pressedButtons`, and the GUI's
    /// shortcuts panel placing itself under the pointer at open —
    /// a one-shot position no suite measures.
    private static let pointerHomes = [
        "KiwiCore+Drag.swift",
        "MouseTracker.swift",
        "ShortcutsPanelController.swift",
    ]

    @Test("the live pointer read stays in its seam homes")
    func pointerReadHomes() throws {
        let sites = try Self.productionTrees.flatMap {
            try SourceScan.identifierSites(
                of: "NSEvent.mouseLocation",
                under: $0
            )
        }
        for home in Self.pointerHomes {
            let reads = sites.filter {
                $0.file.lastPathComponent == home
            }
            #expect(
                reads.count == 1,
                "\(home) reads the pointer \(reads.count) times"
            )
        }
        let strays = sites.filter {
            !Self.pointerHomes.contains($0.file.lastPathComponent)
        }
        let listed = strays.map(\.site).joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "live pointer read outside a seam: \(listed)"
        )
    }

    @Test("the button mask is read in exactly its two homes")
    func buttonsReadOnlyBehindTheSeam() throws {
        let sites = try Self.productionTrees.flatMap {
            try SourceScan.identifierSites(
                of: "NSEvent.pressedMouseButtons",
                under: $0
            )
        }
        // Counted PER FILE, not as a total: a total stays green
        // when a read migrates from one allowed home into the
        // other. One each — zero means the scan looks at the
        // wrong tree or the needle rotted, and a SECOND read
        // grown *inside* an allowed file is exactly what the
        // stray filter below cannot see.
        for home in Self.allowed {
            let reads = sites.filter {
                $0.file.lastPathComponent == home
            }
            #expect(
                reads.count == 1,
                "\(home) reads the mask \(reads.count) times"
            )
        }
        let strays = sites.filter {
            !Self.allowed.contains($0.file.lastPathComponent)
        }
        let listed = strays.map(\.site).joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "live mouse-button read outside the seam: \(listed)"
        )
    }

    /// The live host reads `wireDrag` and the seam defaults
    /// leave on every core a suite builds — the button mask, the
    /// cursor, and since #1532 the reveal-strip read. Deleting a pin from
    /// BOTH twins is otherwise silent: the twins-identical scan
    /// sees only a one-sided deletion, and a behavioural read
    /// answers 0 on a quiet host either way — which is exactly
    /// the run where the defect is invisible. The
    /// `DesktopCensusSeamTests` shape, one subsystem over.
    ///
    /// Residue, same class as the read census above: the needles
    /// are one spelling each, so a pin re-written equivalently
    /// (`{ CGPoint.zero }`) reads as missing. Fail-closed, and
    /// the message names the target it is missing from.
    @Test("makeTestCore pins every live mouse read")
    func testCorePinsEveryMouseRead() throws {
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"]
            .map {
                Self.root.appendingPathComponent(
                    "Tests/\($0)/TestCore.swift"
                )
            }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            // Both twins ARE `TestCore.swift`, so the message
            // names the target directory instead.
            let target = twin.deletingLastPathComponent()
                .lastPathComponent
            #expect(
                source.contains(
                    "mouse.pressedButtons = { 0 }"
                )
                    && source.contains(
                        "drag.cursorLocation = { .zero }"
                    )
                    && source.contains(
                        "mouse.pointerInMenuBarStrip = { false }"
                    ),
                .init(rawValue: "\(target) misses a pin")
            )
        }
    }
}
