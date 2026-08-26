import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The macOS **Desktop** keybinding rows (#884's verbs, GUI
/// half). `ShortcutsFamilyRowsTests` holds that the three
/// families expand once per Desktop; this holds what those rows
/// actually SAY and where they reach — the facts that are wrong
/// silently.
///
/// Its own suite rather than more arms on that one: every
/// assertion here is about the Desktop rows specifically, and
/// three of them (the argument form, the classifier arm, the
/// panel band) are about surfaces that suite does not touch.
@Suite("Desktop shortcut rows")
@MainActor
struct DesktopShortcutRowsTests {

    /// **The Lua argument is a bare number.** The verbs read it
    /// through `intValue`, which answers nil for a string, so a
    /// quoted argument would produce a row that looks right,
    /// records fine, and refuses every time it fires — with the
    /// refusal reaching only the log. Nothing else in this tree
    /// can see that: the row renders, the classifier matches it,
    /// the panel names it.
    ///
    /// Asserted as the whole body rather than by "contains a
    /// digit", because the defect is the quoting.
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
        #expect(rendered.count == expander.desktops.count * 2)
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

    /// A macOS with no Desktop bridge draws NO Desktop rows —
    /// `KiwiCore.bindableDesktops` answers an empty list there,
    /// and an empty list is what makes the three families draw
    /// nothing. Offering them would offer three verbs that
    /// refuse on this machine and can never do otherwise.
    @Test("no Desktops means no Desktop rows")
    func withoutDesktopsNothingIsOffered() {
        let expander = ShortcutsFamilyRows(
            spaces: ["1"],
            icons: [:],
            desktops: [],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
        for key in Self.desktopFamilies {
            #expect(expander.rows(for: key)?.isEmpty == true)
        }
    }

    /// A binding keeps its row when its Desktop stops existing.
    ///
    /// This is the Desktop answer to #92. A Desktop number is
    /// macOS topology, not user data: unplug a screen and
    /// Desktops 3–5 are gone, while the binding that named one
    /// is still Carbon-registered, still blocks the recorder,
    /// and would have no row for the duplicate-combo block's
    /// "Go to" to reach. `offeredDesktops` is the union that
    /// keeps it, and both surfaces consume it.
    @Test("a bound Desktop is offered even when it is gone")
    func aBoundDesktopSurvivesItsScreen() {
        let bindings = [
            KeyBinding(
                combo: "ctrl+alt+5",
                lua: "KiwiDesk.focus_desktop(5)",
                kind: .navigation
            )
        ]
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [1, 2],
                bindings: bindings
            ) == [1, 2, 5]
        )
        // And with the bridge absent entirely, the bound one is
        // still the only thing offered — an empty live list is
        // the capability answer, not a reason to drop a row the
        // user authored.
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [],
                bindings: bindings
            ) == [5]
        )
        // A live Desktop the bindings also name is offered once.
        #expect(
            KeybindingCatalog.offeredDesktops(
                live: [1, 5],
                bindings: bindings
            ) == [1, 5]
        )
    }

    /// A Desktop binding recovered from `init.lua` classifies as
    /// `.navigation` and takes the catalog's own English label —
    /// by SHAPE, so it works for a Desktop that is not attached
    /// right now. Left `.custom` it would render as raw Lua in
    /// the Advanced drawer and in the panel's Custom band.
    @Test("an imported Desktop binding leaves Custom")
    func importClassifiesADesktopRow() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+7",
                        lua: "KiwiDesk.move_to_desktop(7)",
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Move to Desktop 7")
    }

    /// Anything that is not one of the three verbs parses to
    /// nil, so a future `…_desktop` verb taking something else
    /// cannot be swept into these rows, and a Space verb never
    /// is.
    @Test("only the three Desktop verbs parse")
    func onlyTheThreeVerbsParse() {
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.focus_space(\"3\")"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.rename_desktop(3)"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.focus_desktop(\"3\")"
            ) == nil
        )
        #expect(
            KeybindingCatalog.desktopNumber(
                from: "KiwiDesk.move_to_desktop_and_follow(3)"
            ) == 3
        )
    }

    /// A bound Desktop row reaches the ⌃⌥K panel under its real
    /// name, in the band its family is censused in — never the
    /// Custom band, which means "user-authored" and renders raw
    /// Lua untranslated in every locale (#678 item 18 is the
    /// same defect, one family over).
    @Test("a bound Desktop row is a named panel row")
    func panelNamesADesktopRow() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+shift+2",
                        lua: "KiwiDesk.focus_desktop(2)",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "ctrl+alt+cmd+2",
                        lua:
                            "KiwiDesk.move_to_desktop_and_follow(2)",
                        kind: .navigation
                    ),
                ]
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [1, 2],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.custom.isEmpty)
        let labels = reference.controls.flatMap(\.rows).map(
            \.label
        )
        #expect(labels.contains("Go to Desktop 2"))
        #expect(labels.contains("Move to Desktop 2 & follow"))
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
            desktops: [1, 2],
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
    }
}
