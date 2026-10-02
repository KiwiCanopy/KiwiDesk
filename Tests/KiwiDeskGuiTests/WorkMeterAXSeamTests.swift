import Foundation
import Testing

/// Every AX round trip into another app is counted (#1508): an
/// `AXUIElement` call that messages the app runs inside
/// `WorkMeter.shared.ax { … }` in Core, or the per-switch AX count
/// under-reports and the #1508 before/after measures nothing.
/// Local AX calls (`AXUIElementGetPid`, element creation, the
/// messaging timeout, observer registration) send no message and
/// are not in the set.
@Suite("Work meter AX seam (#1508)")
struct WorkMeterAXSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// The messaging calls the meter must see.
    private static let calls = [
        "AXUIElementCopyAttributeValue(",
        "AXUIElementCopyAttributeValues(",
        "AXUIElementSetAttributeValue(",
        "AXUIElementPerformAction(",
        "AXUIElementCopyMultipleAttributeValues(",
        "AXUIElementCopyAttributeNames(",
        "AXUIElementIsAttributeSettable(",
        "AXUIElementGetAttributeValueCount(",
        "AXUIElementCopyParameterizedAttributeValue(",
        "AXUIElementCopyParameterizedAttributeNames(",
        "AXUIElementCopyActionNames(",
        "AXUIElementCopyActionDescription(",
        "AXUIElementCopyElementAtPosition(",
    ]

    /// The calls Core makes today, each of which the scan must
    /// still find wrapped — a liveness floor per call, so a scan
    /// that stops seeing one reds rather than passing on less.
    private static let used = [
        "AXUIElementCopyAttributeValue(",
        "AXUIElementSetAttributeValue(",
        "AXUIElementPerformAction(",
        "AXUIElementCopyMultipleAttributeValues(",
    ]

    private static let wrapper = "WorkMeter.shared.ax {"

    /// (raw calls, wrapped calls per call) in `text`: a call is
    /// wrapped when the code right before it is the wrapper's
    /// brace.
    private static func census(
        in text: String
    ) -> (Int, [String: Int]) {
        var raw = 0
        var wrapped: [String: Int] = [:]
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
                    wrapped[call, default: 0] += 1
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
        var wrapped: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let (raw, ok) = Self.census(in: text)
            wrapped.merge(ok, uniquingKeysWith: +)
            if raw > 0 { offenders.append(file.lastPathComponent) }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "unmetered AX call in \(offenders)")
        )
        for call in Self.used {
            #expect(
                wrapped[call, default: 0] > 0,
                .init(rawValue: "scan no longer finds \(call)")
            )
        }
    }
}
