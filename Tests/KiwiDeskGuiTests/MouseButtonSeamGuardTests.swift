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
/// whichever test happened to be running, and the red moved
/// between suites each time (four different tests in one
/// `MouseWarpHoldTests` session, 2026-08-29). They now read
/// `MouseTracker.pressedButtons`, which `makeTestCore` pins.
///
/// A sibling of `MachineTouchTests` rather than a needle inside
/// it: that file is at the §2.1 ceiling, and this is the same
/// split `StatusItemSeamGuardTests` already carries.
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

    @Test("the button mask is read in exactly its two homes")
    func buttonsReadOnlyBehindTheSeam() throws {
        let sites = try Self.productionTrees.flatMap {
            try SourceScan.identifierSites(
                of: "NSEvent.pressedMouseButtons",
                under: $0
            )
        }
        // Counted, not just filtered: zero means the scan looks
        // at the wrong tree or the needle rotted, and a SECOND
        // read grown *inside* an allowed file is exactly what
        // the stray filter cannot see.
        #expect(sites.count == Self.allowed.count)
        let strays = sites.filter {
            !Self.allowed.contains($0.file.lastPathComponent)
        }
        let listed = strays.map(\.site).joined(separator: ", ")
        #expect(
            strays.isEmpty,
            "live mouse-button read outside the seam: \(listed)"
        )
    }
}
