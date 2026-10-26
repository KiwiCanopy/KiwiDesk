import AppKit
import Testing

@testable import KiwiDeskCore

/// A one-window hover label drops what its item already shows
/// (#2649): an App Bar label draws its title row alone, a Space Bar
/// glyph's label keeps the app's name and drops the icon, and a
/// list keeps the full header.
@Suite("Peek label header (#2649)", .serialized)
@MainActor
struct BarPeekLabelHeaderTests {
    init() { LiquidGlassGate.override = { false } }

    private static let icon = NSImage(size: NSSize(width: 16, height: 16))

    private func row(_ id: UInt32, title: String) -> BarWindowRow {
        BarWindowRow(
            window: WindowID(id),
            pid: 4242,
            app: "Brave",
            title: title,
            icon: Self.icon
        )
    }

    @Test("Each source states its header")
    func sourcesStateTheirHeader() {
        let one = [WindowID(1)]
        let two = [WindowID(1), WindowID(2)]
        #expect(BarPeekSource.appItem(one).header == .none)
        #expect(BarPeekSource.glyph(one).header == .name)
        #expect(BarPeekSource.appItem(two).header == .full)
        #expect(BarPeekSource.glyph(two).header == .full)
        #expect(BarPeekSource.overflow(one).header == .full)
        #expect(BarPeekSource.space(one).header == .full)
        #expect(BarPeekSource.run(one).header == .full)
    }

    @Test("An App Bar label draws its title row alone")
    func appBarLabelHasNoHeader() {
        let content = BarPeekContent(
            rows: [row(1, title: "Hover peek")],
            header: .none
        )
        #expect(content.groups.first?.showsName == false)
        #expect(content.groups.first?.icon == nil)
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf())
        #expect(body.labels.map(\.stringValue) == ["Hover peek"])
        #expect(body.icons.isEmpty)
        #expect(body.targets.map(\.action) == [.window(WindowID(1))])
    }

    @Test("A Space Bar label keeps the name, not the icon")
    func spaceBarLabelKeepsTheName() {
        let content = BarPeekContent(
            rows: [row(1, title: "Hover peek")],
            header: .name
        )
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf())
        #expect(body.labels.map(\.stringValue) == ["Brave", "Hover peek"])
        #expect(body.icons.isEmpty)
    }

    @Test("A list keeps its icon and name")
    func listKeepsTheHeader() {
        let content = BarPeekContent(
            rows: [row(1, title: "A"), row(2, title: "B")],
            checks: true,
            header: .full
        )
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf())
        #expect(body.labels.first?.stringValue == "Brave")
        #expect(body.icons.count == 1)
    }

    /// Core hands each source's header to the content it builds.
    @Test("Core builds each label with its source's header")
    func coreWiresTheHeader() throws {
        let core = makeBarCore()
        core.state.apply(
            .windowCreated(titledWindow(1, app: "Finder", title: "Docs"))
        )
        let app = try #require(
            core.barPeekContent(.appItem([WindowID(1)]), on: nil)
        )
        #expect(app.groups.first?.showsName == false)
        let glyph = try #require(
            core.barPeekContent(.glyph([WindowID(1)]), on: nil)
        )
        #expect(glyph.groups.first?.showsName == true)
        #expect(glyph.groups.first?.icon == nil)
    }
}
