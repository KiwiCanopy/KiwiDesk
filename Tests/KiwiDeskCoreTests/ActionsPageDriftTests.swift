import Foundation
import Testing

@testable import KiwiDeskCore

/// `docs/commands.md` is generated from the command records
/// (#2610): this suite renders it and compares it to the committed
/// file, so a verb added, renamed or re-summarised without a
/// regenerate reds here, with the command that fixes it.
///
/// Run with `KIWIDESK_WRITE_ACTIONS_PAGE=1` to rewrite the page
/// instead; the comparison then passes against what it wrote.
///
/// The `:::unreleased` marker follows the committed page, so the
/// release strip can retire it in place. The trade: a marker
/// deleted by hand before a release goes unnoticed, and an action
/// added after the strip reaches the page unmarked — its own
/// `lua-reference.md` entry, where the row links, carries the
/// marker that release owes.
@Suite("actions page drift")
struct ActionsPageDriftTests {
    private var docs: URL {
        scriptFixtureRepoRoot().appendingPathComponent("docs")
    }

    private func read(_ name: String) throws -> String {
        try String(
            contentsOf: docs.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    @Test("the committed page is the render")
    func pageMatchesTheRecords() throws {
        let path = docs.appendingPathComponent("commands.md")
        let before = try? read("commands.md")
        // The release strip retires the marker in place; a page it
        // has swept renders without one from then on.
        let page = try ActionsPage.render(
            luaReference: try read("lua-reference.md"),
            unreleased: before.map(ActionsPage.isUnreleased) ?? true
        )
        let env = ProcessInfo.processInfo.environment
        if env["KIWIDESK_WRITE_ACTIONS_PAGE"] == "1" {
            try page.write(to: path, atomically: true, encoding: .utf8)
        }
        let committed = try read("commands.md")
        let message =
            "docs/commands.md is stale; run: \(ActionsPage.regenerate)"
        #expect(committed == page, "\(message)")
    }

    @Test("every row is an action a key can run")
    func rowsAreBindableActions() {
        let names = ActionsPage.groups.flatMap(\.entries)
        #expect(!names.isEmpty)
        for entry in names {
            #expect(APIReference.kind(of: entry) == .action)
            #expect(entry.channel != .cli, "\(entry.qualifiedName)")
        }
        let listed = Set(names.map(\.qualifiedName))
        let bindable = APIReference.entries.filter {
            APIReference.kind(of: $0) == .action && $0.channel != .cli
        }
        #expect(listed == Set(bindable.map(\.qualifiedName)))
    }

    @Test("a pending summary refuses the render")
    func pendingSummaryRefuses() throws {
        let reference = try read("lua-reference.md")
        let refusal = #expect(throws: ActionsPage.Refusal.self) {
            try ActionsPage.render(
                luaReference: reference,
                pending: ["focus"]
            )
        }
        #expect(refusal == .pendingSummary("focus"))
    }

    @Test("a row whose heading is gone refuses the render")
    func missingHeadingRefuses() throws {
        let reference = try read("lua-reference.md")
            .replacingOccurrences(of: "### focus\n", with: "### fokus\n")
        let refusal = #expect(throws: ActionsPage.Refusal.self) {
            try ActionsPage.render(luaReference: reference)
        }
        #expect(refusal == .noHeading(["focus"]))
    }

    @Test("a page the release strip swept still matches")
    func strippedPageRenders() throws {
        let reference = try read("lua-reference.md")
        let marked = try ActionsPage.render(luaReference: reference)
        let swept = try ActionsPage.render(
            luaReference: reference,
            unreleased: false
        )
        #expect(ActionsPage.isUnreleased(marked))
        #expect(!ActionsPage.isUnreleased(swept))
        // The release's own sweep, run on the marked page.
        let release = try sweepFixtureCorpus(["commands.md": marked])
        #expect(release.run.status == 0)
        #expect(release.pages["commands.md"] == swept)
    }

    @Test("anchors follow the site's slugger")
    func anchorsAreSlugged() {
        let text = """
            ### focus_space_previous / focus_space_next
            ### stack.promote
            ## Examples
            ### `KiwiDesk.exec`
            ## Examples
            #### save_profile, load_profile
            """
        let anchors = ActionsPage.headingAnchors(in: text)
        #expect(
            anchors["focus_space_next"]
                == "focus_space_previous--focus_space_next"
        )
        #expect(anchors["stack.promote"] == "stackpromote")
        #expect(anchors["exec"] == "kiwideskexec")
        #expect(anchors["load_profile"] == "save_profile-load_profile")
        #expect(anchors["Examples"] == nil)
    }
}
