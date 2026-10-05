import Foundation
import Testing

/// Every own-window front reaches Core (#1861). `forceFront` notes
/// the window's number through `NSApplication.ownFrontNote`, which
/// `AppDelegate` points at `KiwiCore.noteOwnFront(number:)` —
/// `OwnFrontEchoTests` holds what the door does. What a fixture
/// cannot see is the wiring: a `forceFront` that dropped the note,
/// noted before the order-in (a deferred window has no number
/// yet), or a hook nobody installs would go dead with every unit
/// test green.
@Suite("Every own front reaches Core (#1861)")
struct OwnFrontWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )

    private static func body(
        of declaration: String,
        in file: String
    ) throws -> String {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: gui.appendingPathComponent(file),
                encoding: .utf8
            )
        )
        return try #require(
            SourceScan.declarationBody(after: declaration, in: source)
        )
    }

    @Test("forceFront notes the window after ordering it in")
    func forceFrontNotesAfterOrderIn() throws {
        let body = try Self.body(
            of: "func forceFront(_ window: NSWindow) {",
            in: "DockPresentation.swift"
        )
        let order = try #require(
            body.range(of: "window.orderFrontRegardless()")
        )
        let note = try #require(
            body.range(of: "Self.ownFrontNote?(window.windowNumber)")
        )
        let activate = try #require(
            body.range(of: "activate(ignoringOtherApps: true)")
        )
        #expect(order.upperBound <= note.lowerBound)
        #expect(note.upperBound <= activate.lowerBound)
    }

    @Test("AppDelegate installs the hook on Core's door")
    func appDelegateInstallsTheHook() throws {
        let launch = try Self.body(
            of: "func applicationDidFinishLaunching(",
            in: "AppDelegate.swift"
        )
        let install = try #require(
            launch.range(of: "NSApplication.ownFrontNote = {")
        )
        let rest = launch[install.upperBound...]
        #expect(
            rest.prefix(120).contains("noteOwnFront(number: number)")
        )
    }

    /// The door has one GUI caller, the hook: a site calling it
    /// beside `forceFront` would be a second, partial wiring.
    @Test("the door is reached through the hook alone")
    func doorHasOneCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "noteOwnFront(",
            under: Self.gui
        )
        #expect(sites.map(\.file.lastPathComponent) == ["AppDelegate.swift"])
    }
}
