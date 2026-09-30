import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space marker (#1790): a temporary Space wears an hourglass
/// and says so to VoiceOver, a held one a display (#1507), in the
/// one identifier corner — and neither is hidden by the sticky
/// badge switch, which hides the window-state badges alone.
@Suite("Temporary Space marker (#1790)", .serialized)
@MainActor
struct TemporarySpaceBarTests {
    private let desk = HeldSpaceDesk()

    private func view(
        _ item: SpaceBarOverlay.Item,
        style: SpaceBarLook = SpaceBarLook()
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(frame: .zero)
        view.configure(
            identity: item.identity,
            spaceGlyph: item.spaceGlyph,
            apps: [],
            active: false,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(sticky: "", floating: ""),
            held: item.held,
            temporary: item.temporary
        )
        return view
    }

    private func item(
        _ core: KiwiCore,
        _ id: SpaceID
    ) throws -> SpaceBarOverlay.Item {
        try #require(
            [desk.builtIn, desk.dell].flatMap {
                core.spaceBarItems(display: $0.id, style: SpaceBarLook())
            }.first { $0.identity == .space(id) }
        )
    }

    @Test("a temporary Space wears the hourglass and says so")
    func temporaryMarker() throws {
        LocalizationManager.shared.select("en")
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        let temporary = try item(core, SpaceID(7))
        #expect(temporary.temporary)
        #expect(try !item(core, SpaceID(1)).temporary)
        let drawn = view(temporary)
        #expect(!drawn.markerBadge.isHidden)
        #expect(drawn.markerBadge.symbolName == "hourglass")
        #expect(
            drawn.accessibilityLabel()
                == "Space 7, temporary, windows: 0, not current"
        )
    }

    @Test("a held Space wears the display")
    func heldMarker() throws {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        let drawn = view(try item(core, SpaceID(5)))
        #expect(!drawn.markerBadge.isHidden)
        #expect(drawn.markerBadge.symbolName == "display")
    }

    @Test("the sticky badge switch hides neither marker")
    func stickySwitchKeepsMarkers() throws {
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        var style = SpaceBarLook()
        style.bar.stickyBadge = false
        let drawn = view(try item(core, SpaceID(7)), style: style)
        #expect(!drawn.markerBadge.isHidden)
    }
}
