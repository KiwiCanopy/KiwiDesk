import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every Core read of a KiwiVision setting goes through the one
/// resolver, `VisionLook` (#2103 v3): a plain read beside it is
/// wrong only while a lens is on, which no plain-mode suite sees.
@Suite("KiwiVision look seam")
struct VisionLookSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    /// The flat live fields' home and the resolver's, and the
    /// `gui.json` encoder, which writes the stored group whole.
    private static let homes: Set<String> = [
        "Config/AppWideSettings.swift", "Config/VisionLook.swift",
        "Config/GuiConfig.swift",
    ]

    /// Every flat live field a lens can override, read off the
    /// overrides by reflection, and the stored group itself, read
    /// whole or by member (`visionLenses` is a different word).
    private static var needle: String {
        let fields = fieldNamesOf(VisionLens.Overrides()).map {
            "vision" + $0.prefix(1).uppercased() + $0.dropFirst()
        }
        return #"(?<!\$0)\.("# + fields.sorted().joined(separator: "|")
            + #")\b|appWide\.vision\b"#
    }

    private static func fieldNamesOf(_ value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap(\.label)
    }

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
                of: Self.needle,
                options: .regularExpression
            ) != nil {
                readers.append(path)
            }
        }
        #expect(scanned > 100, "the scan reached Core")
        #expect(readers.isEmpty, "read through visionLook: \(readers)")
    }
}
