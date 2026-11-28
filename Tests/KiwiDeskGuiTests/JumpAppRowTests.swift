import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's Applications section, the GUI's half (#3704): which apps
/// are candidates, how a query ranks them, how they join the list's
/// selection and digits, and what each pick does on an app row.
/// Main-actor spend: pure values and one model per test.
@Suite("KiwiHub Applications rows (#3704)")
@MainActor
struct JumpAppRowTests {
    static func app(_ id: String, _ name: String, running: Bool = false)
        -> JumpAppCandidate
    {
        JumpAppCandidate(bundleID: id, name: name, running: running)
    }

    static let candidates = [
        app("a.safari", "Safari"),
        app("a.slack", "Slack", running: true),
        app("a.messages", "Messages"),
        app("a.maps", "Maps"),
    ]

    @Test("listed apps and KiwiDesk leave; a windowless running app stays")
    func build() {
        let built = JumpAppCandidate.build(
            installed: [
                .init(bundleID: "a.mail", name: "Mail"),
                .init(bundleID: "a.notes", name: "Notes"),
                .init(bundleID: "a.kiwi", name: "KiwiDesk"),
            ],
            running: [
                JumpRunningApp(bundleID: "a.mail", name: "Mail", listed: true),
                JumpRunningApp(
                    bundleID: "a.slack",
                    name: "Slack",
                    listed: false
                ),
            ],
            own: "A.Kiwi"
        ).sorted { $0.bundleID < $1.bundleID }
        #expect(
            built == [
                Self.app("a.notes", "Notes"),
                Self.app("a.slack", "Slack", running: true),
            ]
        )
    }

    @Test("a name's start first, running first on a tie, then by name")
    func ranking() {
        let ranked = JumpList.appMatches(Self.candidates, query: "s")
            .map(\.app.name)
        // Slack and Safari start with s, Slack running; Maps and
        // Messages hold it inside, by name.
        #expect(ranked == ["Slack", "Safari", "Maps", "Messages"])
        #expect(JumpList.appMatches(Self.candidates, query: "").isEmpty)
        let many = (0..<8).map { Self.app("a.\($0)", "App \($0)") }
        #expect(
            JumpList.appMatches(many, query: "app").count == JumpList.appCap
        )
    }

    private func list() -> JumpList {
        JumpList(
            snapshot: JumpStripTests.snapshot,
            candidates: Self.candidates
        )
    }

    @Test("under a query the apps follow the windows under their header")
    func joinsTheList() {
        var list = list()
        #expect(list.appResults.isEmpty)
        list.setQuery("s")
        let windows = list.results.count
        #expect(list.appsStart == windows)
        #expect(list.section(at: windows) == .applications)
        #expect(list.rowCount == windows + 4)
        #expect(list.digitReaches(windows))
        // The header and the rows are sized in.
        #expect(list.drawnRows == windows + 4)
        #expect(list.sectionCount == 1)
        list.select(windows + 1)
        #expect(list.selected == nil)
        #expect(list.selectedApp?.app.name == "Safari")
        list.step(1, wrap: false)
        #expect(list.selectedApp?.app.name == "Maps")
        // A tile narrows to one app's windows, and lists no app.
        list.pickTile(1)
        #expect(list.stripApp?.name == "Notes")
        #expect(list.appResults.isEmpty)
        list.pickTile(0)
        #expect(!list.appResults.isEmpty)
    }

    private func model() -> JumpModel {
        let model = JumpModel(
            snapshot: JumpStripTests.snapshot,
            candidates: Self.candidates,
            icons: [:],
            rowCap: 9,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        return model
    }

    @Test("↩ opens; Move here and Swap here beep as dead chords")
    func picks() {
        let model = model()
        var opened: [String] = []
        var dead = 0
        var refused: [String] = []
        model.onOpenApp = { opened.append($0) }
        model.onDeadKey = { dead += 1 }
        model.onRefuse = { refused.append($0) }
        model.query = "safari"
        let row = model.list.results.count
        model.pick(row, .moveHere)
        model.pick(row, .swapHere)
        #expect(dead == 2 && opened.isEmpty && refused.isEmpty)
        model.pick(row, .jump)
        #expect(opened == ["a.safari"])
        // A ⌘ digit and a click reach an app row through the keys'
        // and the row's own doors.
        model.handle(.quick(row, moveHere: false), repeated: false)
        model.clickRow(row, pick: .jump)
        #expect(opened == ["a.safari", "a.safari", "a.safari"])
    }

    @Test("an app Core cannot find refuses in its row")
    func refusal() {
        LocalizationManager.shared.select("en")
        let model = model()
        var opened: [String] = []
        var refused: [String] = []
        model.onOpenApp = { opened.append($0) }
        model.onRefuse = { refused.append($0) }
        model.openRefusal = { _ in .notFound }
        model.query = "safari"
        let row = model.list.results.count
        model.pick(row, .jump)
        #expect(opened.isEmpty)
        #expect(refused == ["Can't open: Safari"])
        #expect(model.revealedRow == row)
    }

    @Test("rows speak as applications; the footer reads ↩ Open")
    func words() {
        LocalizationManager.shared.select("en")
        #expect(
            JumpAppText.spoken(Self.app("a", "Maps"))
                == "Maps, application, not open"
        )
        let slack = Self.app("a", "Slack", running: true)
        #expect(JumpAppText.state(slack) == "Open, no windows")
        let open = JumpFooter(scope: .windows, selectionOpens: true).hints
        #expect(open.first == "↩ Open")
        let model = model()
        model.query = "zzz"
        #expect(model.emptyText == "No Results")
    }

    /// The controller hands Core's answers in and the list draws the
    /// app rows (`JumpPanelController` wiring, by source).
    @Test("the controller wires Core and the list draws app rows")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        func squash(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let controller = try squash("JumpPanelController.swift")
        #expect(controller.contains("candidates:Self.appCandidates(snapshot)"))
        #expect(controller.contains("wireApps(model)"))
        let apps = try squash("JumpPanelController+Apps.swift")
        #expect(
            apps.contains(
                "model.openRefusal={[weakself]inself?.core.openAppRefusal($0)}"
            )
        )
        #expect(apps.contains("core.openApp(bundleID)"))
        #expect(apps.contains("installed:InstalledApps.scanned??[]"))
        // Core's one matcher ranks the rows; no Jump file starts
        // the scan on the hotkey path (#3276).
        let apps2 = try squash("JumpList+Apps.swift")
        #expect(apps2.contains("JumpSearch.nameMatch(query,in:app.name)"))
        #expect(!apps2.contains("range(of:"))
        let jump = try FileManager.default.contentsOfDirectory(
            atPath: root.path
        ).filter { $0.hasSuffix(".swift") }
        #expect(jump.count > 10)
        for file in jump {
            let source = try squash(file)
            #expect(!source.contains("InstalledApps.disk"), "\(file)")
            #expect(!source.contains("InstalledApps.iconPaths"), "\(file)")
            #expect(!source.contains("KeybindingCatalog.installed"), "\(file)")
        }
        let list = try squash("JumpPanelView+List.swift")
        #expect(
            list.contains("ifletapp=list.appRow(index){appRow(index,app)}")
        )
    }
}
