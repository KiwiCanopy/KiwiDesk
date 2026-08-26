import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a macOS **Desktop** keybinding row SAYS (#884's verbs,
/// GUI half): the Lua it authors, the verb that Lua names, and
/// the order the rows render in.
///
/// `DesktopShortcutOfferTests` holds the other half — WHICH
/// Desktops are offered a row at all, and how one whose screen
/// is away is marked. Split at the §2.1 ceiling, at a seam the
/// two halves already had: nothing here reads a live machine,
/// and nothing there reads a Lua body.
///
/// `ShortcutsFamilyRowsTests` holds the per-instance counts.
@Suite("Desktop shortcut rows")
@MainActor
struct DesktopShortcutRowsTests {

    @Test("the rows author a bare-number Lua argument")
    func luaArgumentIsANumber() {
        #expect(
            KeybindingCatalog.goToDesktop([3]).first?.lua
                == "KiwiDesk.focus_desktop(3)"
        )
        #expect(
            KeybindingCatalog.moveToDesktopRows([3]).first?.lua
                == "KiwiDesk.move_to_desktop(3)"
        )
        #expect(
            KeybindingCatalog.moveToDesktopFollowRows([3])
                .first?.lua
                == "KiwiDesk.move_to_desktop_and_follow(3)"
        )
    }

    /// The wire names the three rows author are the three the
    /// dispatcher answers to. Derived from `APIReference` rather
    /// than restated: a verb renamed there with the catalog left
    /// behind gives a row that refuses with "unknown command",
    /// and #1009 already records that every existing guard
    /// checks the catalogue against itself.
    @Test("every Desktop row names a registered verb")
    func rowsNameRegisteredVerbs() {
        let registered = Set(APIReference.commands.map(\.lua))
        let rows =
            KeybindingCatalog.goToDesktop([1])
            + KeybindingCatalog.moveToDesktop([1])
        #expect(!rows.isEmpty)
        for row in rows {
            let verb = row.lua
                .replacingOccurrences(of: "KiwiDesk.", with: "")
                .prefix { $0 != "(" }
            #expect(
                registered.contains(String(verb)),
                Comment(rawValue: "\(row.lua) names no verb")
            )
        }
    }

    /// Each family draws its OWN verb. Counts cannot see a swap
    /// — the three lists are the same length — and a follow row
    /// under the plain heading moves a window and takes the user
    /// with it, which is the opposite of what the row promised.
    @Test("the three Desktop families draw different verbs")
    func familiesAreDistinct() {
        let expander = fixture()
        let focus =
            expander.rows(for: .shortcuts(.focusDesktop)) ?? []
        let plain =
            expander.rows(for: .shortcuts(.moveToDesktop)) ?? []
        let follow =
            expander.rows(for: .shortcuts(.moveToDesktopFollow))
            ?? []
        #expect(!focus.isEmpty && !plain.isEmpty)
        #expect(!follow.isEmpty)
        #expect(
            focus.allSatisfy {
                $0.lua.contains("KiwiDesk.focus_desktop(")
            }
        )
        #expect(
            plain.allSatisfy {
                $0.lua.contains("KiwiDesk.move_to_desktop(")
            }
        )
        #expect(
            follow.allSatisfy {
                $0.lua.contains("move_to_desktop_and_follow")
            }
        )
    }

    /// The per-Desktop move pair renders interleaved — plain,
    /// follow, plain, follow — for the reason the per-Space pair
    /// does: "Move to Desktop 2" and "…& follow" are one
    /// decision about one Desktop. Set equality over the order
    /// list is order-blind, so this is the only place it can be
    /// held.
    @Test("the per-Desktop move rows interleave by Desktop")
    func moveRowsInterleave() {
        let expander = fixture()
        let rendered = expander.renderedRows(
            for: .shortcuts(.moveToDesktop)
        )
        #expect(rendered.count == expander.desktops.desktops.count * 2)
        for (offset, command) in rendered.enumerated() {
            let isFollow = command.lua.contains(
                "move_to_desktop_and_follow"
            )
            #expect(
                isFollow == (offset % 2 == 1),
                Comment(rawValue: "row \(offset) is out of pair")
            )
        }
        // The follower draws nothing of its own, or every row
        // would appear twice.
        #expect(
            expander.renderedRows(
                for: .shortcuts(.moveToDesktopFollow)
            )
            .isEmpty
        )
    }
    private static let desktopFamilies: [SettingKey] = [
        .shortcuts(.focusDesktop),
        .shortcuts(.moveToDesktop),
        .shortcuts(.moveToDesktopFollow),
    ]

    /// Pins every input an expansion reasons from, so a moved
    /// default reds as a default. Two Desktops against three
    /// spaces, deliberately: see `instanceCounts`.
    private func fixture() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(desktops: [1, 2]),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }
}
