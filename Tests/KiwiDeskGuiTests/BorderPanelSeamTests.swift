import Foundation
import Testing

/// The ring panel's WindowServer writes stay behind their seams
/// (#1956): the SkyLight move defaults LIVE on `BorderManager`
/// alone, and both `makeTestCore` twins pin it, with the level read
/// beside it, to the AppKit fallback. Twin
/// IDENTITY is `MachineTouchTests`'; a pin deleted from both twins
/// passes it, which is the half held here. And a default regressed
/// to the fallback reds nothing behavioural — every suite pins the
/// seam — so the live default is held by its spelling.
@Suite("Border panel seams stay injected")
struct BorderPanelSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// Whitespace runs collapsed, so a needle spans a wrapped
    /// declaration.
    private static func flattened(_ source: String) -> String {
        source.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }

    @Test("both twins pin the ring panel's WindowServer seams")
    func twinsPinThePanelSeams() throws {
        let tests = Self.root.appendingPathComponent("Tests")
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: tests.appendingPathComponent("\(twin)/TestCore.swift")
            )
            for pin in [
                "core.borders.movePanel = { _, _ in false }",
                "core.borders.windowLevel = { _ in nil }",
            ] {
                #expect(source.contains(pin), "\(twin) misses \(pin)")
            }
        }
    }

    @Test("the manager's panel move defaults to the live SkyLight one")
    func managerDefaultsAreLive() throws {
        let source = Self.flattened(
            try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(
                    "Borders/BorderManager.swift"
                )
            )
        )
        try #require(!source.isEmpty)
        #expect(
            source.contains(
                "var movePanel: (CGWindowID, CGPoint) -> Bool "
                    + "= SkyLight.moveWindow"
            )
        )
    }

    /// One live move in Core: an inner initializer that defaulted
    /// it as well would hand every direct construction the live
    /// write, unpinned.
    @Test("the live panel move has one home, the manager's default")
    func liveMoveHasOneHome() throws {
        let sites = try SourceScan.identifierSites(
            of: "SkyLight.moveWindow",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent) == ["BorderManager.swift"],
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }
}
