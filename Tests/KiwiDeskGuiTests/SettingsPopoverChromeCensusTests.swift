import Foundation
import Testing

@testable import KiwiDesk

/// Every popover in the GUI tree wears the one Settings surface,
/// `settingsPopoverChrome()` (#2503), or is ruled out here with its
/// reason — by #2399's test, a popover whose meaning rides in fills
/// or hues stays off glass. Off the main actor: a source walk.
@Suite("Settings popover chrome census")
struct SettingsPopoverChromeCensusTests {
    /// File name and the content a popover opens with → why it
    /// stays on the material. The one copy of who may.
    private static let exempt: [String: String] = [
        "SettingsFooter+Unsaved.swift unsavedPopover":
            "the change list's Keep and ↺ fills and value swatches",
        "ScreenCard.swift WrapChips":
            "its overflow Space chips carry fills",
        "FollowsMainTray.swift WrapChips":
            "its overflow Space chips carry fills",
    ]

    /// Each `.popover(` call's content closure, by file name.
    private static func popoverBodies() throws -> [(String, String)] {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var bodies: [(String, String)] = []
        for file in try SourceScan.swiftSources(under: tree) {
            // Comments and literals blanked, so the walk below
            // never balances on a brace inside one.
            let text = Array(try SourceScan.blankedSource(at: file))
            var i = 0
            let needle = Array(".popover(")
            while i + needle.count <= text.count {
                guard Array(text[i..<i + needle.count]) == needle else {
                    i += 1
                    continue
                }
                var cursor = i + needle.count - 1
                _ = SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
                let body =
                    SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "{",
                        close: "}"
                    ) ?? ""
                bodies.append((file.lastPathComponent, body))
                // On past the call, not the closure: a popover
                // nested in another's content is its own site.
                i += needle.count
            }
        }
        return bodies
    }

    @Test("every popover wears the surface or is ruled out")
    func everyPopoverIsRuled() throws {
        let bodies = try Self.popoverBodies()
        // A walk that found nothing would pass for having no strays.
        #expect(bodies.count > 20)
        var bare: Set<String> = []
        for (file, body) in bodies {
            let content = body.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            #expect(!content.isEmpty, "\(file): a popover with no content")
            // The trailing modifier, so the whole content wears it,
            // never one branch or one row of it.
            if !content.hasSuffix(".settingsPopoverChrome()") {
                let root = content.prefix {
                    $0.isLetter || $0.isNumber || $0 == "_"
                }
                bare.insert("\(file) \(root)")
            }
        }
        #expect(
            bare == Set(Self.exempt.keys),
            """
            a popover off the Settings surface: end its content with \
            `settingsPopoverChrome()`, or rule it in `exempt` with \
            its reason (#2399's test). Off it: \(bare.sorted())
            """
        )
    }

    /// A background set beside the surface would hide it, or put an
    /// exempt popover somewhere other than on the material.
    @Test("the popover background is set in one home")
    func backgroundHasOneHome() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var homes: [String] = []
        for file in try SourceScan.swiftSources(under: tree) {
            let source = try SourceScan.blankedSource(at: file)
            if source.contains("presentationBackground") {
                homes.append(file.lastPathComponent)
            }
        }
        #expect(homes == ["SettingsPopoverChrome.swift"])
    }

    /// The surface is the icon picker's, which the owner kept on
    /// device (#2399): untinted glass over the popover material.
    @Test("the surface is glass through the one modifier")
    func surfaceIsGlass() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "SettingsPopoverChrome.swift"
            )
        let source = try SourceScan.blankedSource(at: file)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("presentationBackground{"))
        #expect(source.contains("Color.clear.glassChrome("))
        #expect(source.contains("enabled:true,variant:.regular,"))
    }
}
