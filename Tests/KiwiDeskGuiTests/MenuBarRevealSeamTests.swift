import Foundation
import Testing

/// The #1532 return's wiring, which no behavioural test can red
/// on: the live strip read stays behind its seam, both
/// `makeTestCore` twins pin it, and the arm sits where the
/// ruling puts it — after the placement bounce, before the
/// #958 return, once.
@Suite("Menu-bar reveal return seams (#1532)")
struct MenuBarRevealSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// The pointer read's homes in Core: the drag pipeline's
    /// cursor seam (#1103) and the reveal-strip seam. One each,
    /// counted per file so a read migrating between the homes
    /// cannot pass as a total.
    private static let pointerHomes = [
        "KiwiCore+Drag.swift",
        "MouseTracker.swift",
    ]

    @Test("the live pointer read stays in its two seam homes")
    func pointerReadHomes() throws {
        let sites = try SourceScan.identifierSites(
            of: "NSEvent.mouseLocation",
            under: Self.core
        )
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

    @Test("makeTestCore pins the strip read in both twins")
    func testCorePinsTheStripRead() throws {
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"]
            .map {
                Self.root.appendingPathComponent(
                    "Tests/\($0)/TestCore.swift"
                )
            }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            let target = twin.deletingLastPathComponent()
                .lastPathComponent
            #expect(
                source.contains(
                    "mouse.pointerInMenuBarStrip = { false }"
                ),
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }

    /// The re-assert is the focus COMMAND, never a bare raise:
    /// through `focusWindow` the raise mints a self stamp, so the
    /// report that follows is intended (#1281) instead of the
    /// clickless focus the scrolling placement distrust bounces
    /// (#1414's class). A fixture has no element to raise, so
    /// this is a source clause; `DesktopRaiseGateSeamTests`
    /// separately keeps `AXHelper.raise(` out of the file.
    @Test("the return goes through the focus command")
    func returnTakesTheCommand() throws {
        let arm = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+MenuBarRevealReturn.swift"
            )
        )
        #expect(
            arm.components(separatedBy: "focusWindow(").count == 2
        )
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
