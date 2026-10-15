import Foundation
import Testing

@testable import KiwiDesk

/// Every Core read of a KiwiVision setting goes through the one
/// resolver, `VisionLook` (#2103 v3): a plain read beside it is
/// wrong only while a lens is on, which no plain-mode suite sees.
@Suite("KiwiVision look seam")
struct VisionLookSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    /// The flat live fields' home and the resolver's.
    private static let homes: Set<String> = [
        "Config/AppWideSettings.swift", "Config/VisionLook.swift",
    ]

    @Test("no Core file reads a KiwiVision setting beside the resolver")
    func oneDoor() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        var readers: [String] = []
        var scanned = 0
        let files = FileManager.default.enumerator(
            at: core,
            includingPropertiesForKeys: nil
        )
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = url.path.replacingOccurrences(
                of: core.path + "/",
                with: ""
            )
            scanned += 1
            guard !Self.homes.contains(path) else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            if source.range(
                of: #"appWide\.vision[A-Z]"#,
                options: .regularExpression
            ) != nil {
                readers.append(path)
            }
        }
        #expect(scanned > 100, "the scan reached Core")
        #expect(readers.isEmpty, "read through visionLook: \(readers)")
    }
}
