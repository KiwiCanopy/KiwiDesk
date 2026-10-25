import Foundation
import Testing

@testable import KiwiDesk

/// The Lua bindings drawer names where the actions are (#2610):
/// the link is mounted in the drawer, and its URL is the route the
/// site builds from the generated `docs/commands.md`.
@Suite("Actions list link")
struct ActionsListLinkTests {
    @Test("the drawer mounts the link")
    func drawerMountsTheLink() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
            )
        let text = try SourceScan.strippedSource(at: file)
        guard let drawer = text.range(of: "private var luaDrawer") else {
            Issue.record("the Lua bindings drawer moved")
            return
        }
        let body = text[drawer.upperBound...]
        let end =
            body.range(of: "private var advancedDrawerCaption")?
            .lowerBound ?? body.endIndex
        #expect(body[..<end].contains("ActionsListLink()"))
    }

    @Test("the link opens the generated page's route")
    func urlIsThePage() {
        let url = SupportLinks.actions
        #expect(url.host == "kiwidesk.kiwicanopy.com")
        #expect(url.path == "/docs/commands")
        let page = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("docs/commands.md")
        #expect(FileManager.default.fileExists(atPath: page.path))
    }
}
