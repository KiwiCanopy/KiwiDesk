import Foundation
import Testing

/// Every AX round trip into another app is counted (#1508): a raw
/// attribute read, attribute write, action or multi-attribute read
/// in Core runs inside `WorkMeter.shared.ax { … }`, or the
/// per-switch AX count under-reports and the #1508 before/after
/// measures nothing. Local AX calls (`AXUIElementGetPid`,
/// element creation, observer registration) send no message and
/// are not in the set.
@Suite("Work meter AX seam (#1508)")
struct WorkMeterAXSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// The messaging calls the meter must see.
    private static let calls = [
        "AXUIElementCopyAttributeValue(",
        "AXUIElementSetAttributeValue(",
        "AXUIElementPerformAction(",
        "AXUIElementCopyMultipleAttributeValues(",
    ]

    private static let wrapper = "WorkMeter.shared.ax {"

    /// (raw calls, wrapped calls) in `text`: a call is wrapped
    /// when the code right before it is the wrapper's brace.
    private static func census(in text: String) -> (Int, Int) {
        var raw = 0
        var wrapped = 0
        for call in calls {
            var cursor = text.startIndex
            while let hit = text.range(
                of: call,
                range: cursor..<text.endIndex
            ) {
                cursor = hit.upperBound
                let before = text[..<hit.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if before.hasSuffix(wrapper) {
                    wrapped += 1
                } else {
                    raw += 1
                }
            }
        }
        return (raw, wrapped)
    }

    @Test("no AX message in Core bypasses the meter")
    func everyCallIsMetered() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        #expect(!files.isEmpty)
        var offenders: [String] = []
        var wrapped = 0
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let (raw, ok) = Self.census(in: text)
            wrapped += ok
            if raw > 0 { offenders.append(file.lastPathComponent) }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "unmetered AX call in \(offenders)")
        )
        // Liveness: the scan still finds the sites it guards.
        #expect(wrapped >= Self.calls.count)
    }
}
