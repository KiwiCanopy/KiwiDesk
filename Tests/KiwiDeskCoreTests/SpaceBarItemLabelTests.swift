import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_item_label` (#1535): a Space item is named by
/// its identifier, or by its current layout's symbol — the one
/// `LayoutMode.symbol` the Layout menu draws. An option, never a
/// fallback: the identifier stays the default.
@Suite("Space bar item label", .serialized)
@MainActor
struct SpaceBarItemLabelTests {
    private let display = DisplayID(7)

    /// Spaces 1 (bsp) and "mail" (scrolling) on one display,
    /// one window each.
    private func seededCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-item-label-\(UUID().uuidString)"
                )
        )
        for id in ["1", "mail"] {
            core.state.workspaces.assign(SpaceID(id), to: display)
        }
        core.state.workspaces.activate(SpaceID("mail"))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Notes")))
        core.execute(
            "set_mode",
            args: [.string("mail"), .string("scrolling")]
        )
        return core
    }

    private func window(_ id: UInt32, app: String) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: app,
            title: "Doc",
            isFloating: false
        )
    }

    /// The labels the bar builds, read through the settings the
    /// command wrote — the verb and the builder in one reading.
    private func labels(_ core: KiwiCore) -> [SpaceID: SpaceGlyph] {
        let built = core.spaceBarItems(
            display: display,
            style: core.tiler.settings.spaceBarLook
        )
        return Dictionary(
            uniqueKeysWithValues: built.compactMap { item in
                item.space.map { ($0, item.spaceGlyph) }
            }
        )
    }

    @Test("The identifier is the default")
    func identifierIsTheDefault() {
        #expect(SpaceBarStyle().itemLabel == .identifier)
        let core = seededCore()
        #expect(
            labels(core) == [
                SpaceID("1"): .text("1", tinted: true),
                SpaceID("mail"): .text("MA", tinted: true),
            ]
        )
    }

    @Test("Layout names each Space by its own mode's symbol")
    func layoutDrawsTheModeSymbol() throws {
        let core = seededCore()
        let response = core.execute(
            "space_bar.set_item_label",
            args: [.string("layout")]
        )
        #expect(response.isSuccess)
        #expect(core.tiler.settings.spaceBarStyle.itemLabel == .layout)
        #expect(
            labels(core) == [
                SpaceID("1"): .symbol(LayoutMode.bsp.symbol),
                SpaceID("mail"): .symbol(LayoutMode.scrolling.symbol),
            ]
        )
        // The app glyphs are untouched by the label.
        let built = core.spaceBarItems(
            display: display,
            style: core.tiler.settings.spaceBarLook
        )
        let mail = try #require(
            built.first { $0.space == SpaceID("mail") }
        )
        #expect(mail.apps.map(\.name) == ["Mail"])
    }

    @Test("The label follows a layout change")
    func followsAModeChange() {
        let core = seededCore()
        core.execute(
            "space_bar.set_item_label",
            args: [.string("layout")]
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        #expect(
            labels(core)[SpaceID("1")]
                == .symbol(LayoutMode.monocle.symbol)
        )
    }

    @Test("An unknown label is refused and changes nothing")
    func unknownLabelIsRefused() {
        let core = seededCore()
        let response = core.execute(
            "space_bar.set_item_label",
            args: [.string("icon")]
        )
        #expect(!response.isSuccess)
        #expect(
            core.tiler.settings.spaceBarStyle.itemLabel == .identifier
        )
    }

    @Test("Every layout's symbol is a distinct system symbol")
    func everyModeSymbolResolves() {
        for mode in LayoutMode.allCases {
            #expect(
                KiwiCore.iconIsSymbol(mode.symbol),
                "\(mode) names no SF Symbol"
            )
        }
        let symbols = LayoutMode.allCases.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test("The label survives a JSON round trip under item_label")
    func codingKey() throws {
        var style = SpaceBarStyle()
        style.itemLabel = .layout
        let data = try JSONEncoder().encode(style)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["item_label"] as? String == "layout")
        let back = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: data
        )
        #expect(back.itemLabel == .layout)
    }
}
