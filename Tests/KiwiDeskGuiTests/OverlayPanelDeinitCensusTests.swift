import Foundation
import Testing

/// Every Core type that stores an `NSPanel` orders it out in an
/// `isolated deinit` (#1868). AppKit keeps an ordered-in window
/// alive after its owner is gone, so an overlay dropped while
/// shown leaves its panel on screen; in the test run that piled
/// up hundreds of panels and slowed every WindowServer call.
/// `OverlayPanelReleaseTests` proves the behaviour for the shelf
/// and the sticky mark; this census holds the class.
@Suite("Overlay panel deinit census (#1868)")
struct OverlayPanelDeinitCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// A stored property typed `NSPanel` or `NSPanel?` — never a
    /// subclass declaration (`class X: NSPanel`).
    private static let storedPanel = try! NSRegularExpression(
        pattern: #"\b(?:var|let)\s+\w+\s*:\s*NSPanel\??(?![\w])"#
    )

    private func storesPanel(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return Self.storedPanel.firstMatch(in: text, range: range)
            != nil
    }

    @Test("every file storing a panel releases it in a deinit")
    func everyOwnerReleases() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        var owners: [String] = []
        var offenders: [String] = []
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            guard storesPanel(text) else { continue }
            owners.append(file.lastPathComponent)
            if !text.contains("isolated deinit") {
                offenders.append(file.lastPathComponent)
            }
        }
        // The scan must still see the overlays it was written for.
        #expect(owners.contains("ShelfOverlay.swift"))
        #expect(owners.contains("StickyMarkOverlay.swift"))
        #expect(
            offenders.isEmpty,
            .init(rawValue: "no isolated deinit in \(offenders)")
        )
    }
}
