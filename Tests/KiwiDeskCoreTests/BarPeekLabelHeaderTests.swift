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
        expectEqual(BarPeekSource.appItem(one).header, .none)
        expectEqual(BarPeekSource.glyph(one).header, .name)
        expectEqual(BarPeekSource.appItem(two).header, .full)
        expectEqual(BarPeekSource.glyph(two).header, .full)
        expectEqual(BarPeekSource.overflow(one).header, .full)
        expectEqual(BarPeekSource.space(one).header, .full)
        expectEqual(BarPeekSource.run(one).header, .full)
    }

    @Test("An App Bar label draws its title row alone")
    func appBarLabelHasNoHeader() {
        let content = BarPeekContent(
            rows: [row(1, title: "Hover peek")],
            header: .none
        )
        expectEqual(content.header, .none)
        // A peek cut to fit keeps its header.
        expectEqual(content.keeping(1).header, .none)
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf())
        expectEqual(body.labels.map(\.stringValue), ["Hover peek"])
        #expect(body.icons.isEmpty)
        expectEqual(body.targets.map(\.action), [.window(WindowID(1))])
    }

    @Test("A Space Bar label keeps the name, not the icon")
    func spaceBarLabelKeepsTheName() {
        let content = BarPeekContent(
            rows: [row(1, title: "Hover peek")],
            header: .name
        )
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf())
        expectEqual(body.labels.map(\.stringValue), ["Brave", "Hover peek"])
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
        expectEqual(body.labels.first?.stringValue, "Brave")
        expectEqual(body.icons.count, 1)
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
        expectEqual(app.header, .none)
        let glyph = try #require(
            core.barPeekContent(.glyph([WindowID(1)]), on: nil)
        )
        expectEqual(glyph.header, .name)
    }
}
