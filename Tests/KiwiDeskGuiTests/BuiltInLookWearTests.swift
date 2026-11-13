import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A built-in applies wearing the shared look (#1752), so a picture
/// of one wears it too: a reader of `StandardLayout.settings(sizes:)`
/// in the GUI paints the look over it through `LookBody.worn(over:)`
/// or draws colours and gaps the applied built-in will not have
/// (profiles.md, gui.md #702).
@Suite("Built-in look wear (#1752)")
struct BuiltInLookWearTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Path under `Sources/KiwiDesk` → how its read of a built-in's
    /// settings wears the look.
    /// None since the Profiles presets left Settings (#3294): the
    /// tour draws the live settings, never a built-in's own.
    private static let allowed: [String: String] = [:]

    /// A call of `settings(sizes:)`, implicit `self` and spacing
    /// included.
    private static var read: Regex<Substring> {
        #/(?:^|[^A-Za-z0-9_])settings\(\s*sizes\s*:/#
    }

    /// A new GUI reader of a built-in's settings reds until it wears
    /// the look and is given its reason above.
    @Test("every GUI read of a built-in's settings is registered")
    func everyReadIsRegistered() throws {
        let gui = Self.root.appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: gui)
        #expect(!files.isEmpty)
        var readers: Set<String> = []
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            if text.firstMatch(of: Self.read) != nil {
                readers.insert(
                    String(file.path.dropFirst(gui.path.count + 1))
                )
            }
        }
        #expect(readers == Set(Self.allowed.keys))
    }
}
