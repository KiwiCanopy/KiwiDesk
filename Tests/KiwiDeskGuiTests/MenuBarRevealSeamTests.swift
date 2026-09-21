import Foundation
import Testing

/// The #1532 return's wiring, which no behavioural test can red
/// on: the re-assert is the stamped raise, and the arm sits
/// where the ruling puts it — after the placement bounce, before
/// the #958 return, once. The strip read's home and the twins'
/// pins are `MouseButtonSeamGuardTests`', the register of every
/// live mouse read.
@Suite("Menu-bar reveal return seams (#1532)")
struct MenuBarRevealSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// The re-assert is the STAMPED raise: `raiseWindow` mints the
    /// self stamp so the report that follows is our own echo
    /// (#1281's point) — never a bare `AXHelper.raise(`, whose
    /// echo the scrolling placement distrust bounces (#1414's
    /// class), and never the focus command, whose displacement
    /// note arms that same bounce against every later report.
    /// A fixture has no element to raise, so this is a source
    /// clause; `DesktopRaiseGateSeamTests` separately keeps
    /// `AXHelper.raise(` out of the file.
    @Test("the return is the stamped raise")
    func returnTakesTheStampedRaise() throws {
        let arm = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+MenuBarRevealReturn.swift"
            )
        )
        #expect(
            arm.components(separatedBy: "raiseWindow(").count == 2
        )
        #expect(!arm.contains("focusWindow("))
        #expect(!arm.contains("AXHelper.raise("))
    }

    /// The arm's one call site, in ORDER: below the placement
    /// bounce (a scrolling pan's bounce keeps its renewing
    /// re-assert) and above the #958 return (which stays last,
    /// so a report this arm takes never spends that one-shot).
    @Test("the arm is consulted once, between #1161 and #958")
    func armOrder() throws {
        let sites = try SourceScan.identifierSites(
            of: "returnMenuBarReveal(",
            under: Self.core
        )
        let calls = sites.filter {
            $0.file.lastPathComponent
                == "KiwiCore+FocusEvents.swift"
        }
        let listed = sites.map(\.site).joined(separator: ", ")
        #expect(calls.count == 1, "found \(listed)")
        let homes = sites.filter {
            $0.file.lastPathComponent
                == "KiwiCore+MenuBarRevealReturn.swift"
        }
        #expect(homes.count == 1)
        #expect(sites.count == 2)
        let handler = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+FocusEvents.swift"
            )
        )
        let bounce = try #require(
            handler.range(of: "reassertAgainstPlacementBounce(")
        )
        let reveal = try #require(
            handler.range(of: "returnMenuBarReveal(")
        )
        let steal = try #require(
            handler.range(of: "returnAccessibilitySteal(")
        )
        #expect(bounce.lowerBound < reveal.lowerBound)
        #expect(reveal.lowerBound < steal.lowerBound)
    }
}
