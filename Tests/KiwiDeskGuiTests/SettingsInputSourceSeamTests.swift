import Foundation
import Testing

@testable import KiwiDesk

/// #991's own condition on its fix: the input-source reading
/// "becomes one seam consulted by every focus-destination site,
/// not a per-site condition, or the next site will forget it".
///
/// That is two claims about SHAPE, and this suite holds both.
/// Neither can say a ring stopped being drawn — only a device
/// with keyboard navigation ON does that — but a second reader
/// appearing beside a view is exactly how the one seam stops
/// being one, and nothing else in the tree would notice.
@Suite("Settings input source is one seam (#991)")
struct SettingsInputSourceSeamTests {
    /// Reach, stated: the scan covers the Settings tree only.
    /// `StatusItemController+Menu.swift` reads the same property
    /// outside it and is not in scope — it is a menu-bar
    /// behaviour, not a focus destination, and folding it in
    /// would make this suite's subject two different things.
    @Test("only the seam reads what macOS is dispatching")
    func oneReaderOfTheCurrentEvent() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        var readers: [String] = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            if source.contains("NSApp.currentEvent") {
                readers.append(file.lastPathComponent)
            }
        }
        #expect(
            readers == ["SettingsInputSource.swift"],
            Comment(
                rawValue:
                    "the current event is read in \(readers) — "
                    + "#991's fix is a seam every focus "
                    + "destination consults, and a second reader "
                    + "beside a view is the per-site condition "
                    + "the issue refused. Route it through "
                    + "`SettingsInputSource`."
            )
        )
    }

    /// The other half: a seam nothing consults is not a seam. If
    /// a future edit drops the gate from both focus statements,
    /// the needle above still passes — the seam would simply sit
    /// there unread.
    @Test("both focus statements consult the recorded source")
    func bothStatementsConsultTheSeam() throws {
        let expected = [
            "SettingsView.swift": "the arrival raise",
            "HomeScreen.swift": "the return restore",
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        for (name, which) in expected {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "\(name) is gone"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            #expect(
                source.contains("nav.navigationFromKeyboard"),
                Comment(
                    rawValue:
                        "\(name) states a focus destination "
                        + "without consulting the input source — "
                        + "\(which) then fires on a mouse "
                        + "navigation and draws a ring macOS "
                        + "would not have drawn (#991)"
                )
            )
        }
    }
}
