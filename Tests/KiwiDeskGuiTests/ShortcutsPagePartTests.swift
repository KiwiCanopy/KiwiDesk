import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts page builds its parts lazily (#3060), so a scroll to
/// a row goes to the row's part first. These hold that every anchor
/// the page draws names its part — a miss falls back to building the
/// whole page, slow but correct — and the wiring that takes the
/// detour.
@Suite("Shortcuts page parts")
@MainActor
struct ShortcutsPagePartTests {
    /// Every catalog control declared for the page, drawers' children
    /// included, names a part. Which part is review's: a second table
    /// of right answers would be one more hand copy of
    /// `catalogOwners` (gui.md ▸ the Shortcuts page's lazy parts).
    @Test("every catalog control names its part")
    func catalogControlsHaveParts() {
        let expander = Self.expander()
        let controls = Self.controls(in: SettingsCatalog.shortcuts)
        #expect(controls.count > 20)
        for control in controls {
            #expect(
                ShortcutsPagePart.owner(
                    of: control.id,
                    expander: expander,
                    bindings: []
                )
                    != nil,
                "no part draws \(control.id)"
            )
        }
    }

    /// A census row placed on the page lands in a part, so a diff-row
    /// jump to its label key finds where to scroll first.
    @Test("every census container on the page is a part")
    func censusContainersArePartsOfThePage() {
        let expander = Self.expander()
        var checked = 0
        for key in SettingKey.allCases {
            guard let area = key.placement.area,
                SettingsDestination(area: area) == .shortcuts,
                let container = key.placement.container,
                case .key(let label) = key.text.label
            else { continue }
            checked += 1
            #expect(
                ShortcutsPagePart(container) != nil,
                "no part draws \(container)"
            )
            #expect(
                ShortcutsPagePart.owner(
                    of: label,
                    expander: expander,
                    bindings: []
                )
                    == ShortcutsPagePart(container)
            )
        }
        #expect(checked > 20)
    }

    /// A shortcut row's id is its command: the recorder's Go to names
    /// it, and it resolves through the family the row expands from.
    @Test("a shortcut row finds its group's part")
    func rowsFindTheirPart() throws {
        let expander = Self.expander()
        let focus = try #require(KeybindingCatalog.focusDirections.first)
        #expect(
            ShortcutsPagePart.owner(
                of: focus.lua,
                expander: expander,
                bindings: []
            )
                == .focus
        )
        #expect(
            ShortcutsPagePart.owner(
                of: "no such row",
                expander: expander,
                bindings: []
            )
                == nil
        )
    }

    /// The chips and the parts agree: each chip's group is drawn in
    /// the part it scrolls to.
    @Test("each chip scrolls to its own group's part")
    func chipsMatchParts() {
        for group in ShortcutsJumpGroup.allCases {
            #expect(ShortcutsPagePart(group).group == group)
            #expect(
                ShortcutsPagePart(group.container) == ShortcutsPagePart(group)
            )
        }
    }

    /// A Mouse & trackpad strip click lands on its entry, inside the
    /// built gestures part: no whole-page rebuild, which would end the
    /// play the click started.
    @Test("every gesture entry is in the gestures part")
    func gestureEntriesHaveTheirPart() {
        let expander = Self.expander()
        for item in GestureItem.allCases {
            #expect(
                ShortcutsPagePart.owner(
                    of: item.anchor,
                    expander: expander,
                    bindings: []
                ) == .gestures
            )
        }
    }

    /// The recorder names an app or Lua row by its binding's id and
    /// an app's pocket key by its Lua; each finds its own part rather
    /// than the page.
    @Test("a binding row finds its part by kind")
    func bindingRowsFindTheirPart() {
        let app = KeyBinding(
            combo: "",
            lua: "kiwi.open_app(\"Safari\")",
            kind: .application,
            label: "Safari"
        )
        let lua = KeyBinding(
            combo: "",
            lua: "print(1)",
            kind: .custom,
            label: ""
        )
        // An app's pocket key is a navigation row, named by its Lua.
        let pocket = KeybindingCatalog.pocketApp("com.apple.Safari").lua
        let expander = Self.expander()
        let rows = [app, lua]
        let parts = (rows.map(\.id.uuidString) + [pocket]).map {
            ShortcutsPagePart.owner(
                of: $0,
                expander: expander,
                bindings: rows
            )
        }
        #expect(parts == [.openApplications, .luaBindings, .pocket])
    }

    /// A reveal outside Shortcuts takes no detour; inside, a held part
    /// needs none, an unbuilt one is reached first, and an unplaceable
    /// anchor asks for the whole page.
    @Test("a reveal lands through its part only where it must")
    func revealLandings() {
        let model = makeTestModel()
        let anchor = SettingsCatalog.shortcuts.focusKeys.id
        model.destination = .spaces
        #expect(model.revealLanding(for: anchor) == nil)
        model.destination = .shortcuts
        #expect(
            model.revealLanding(for: anchor)
                == .part(ShortcutsPagePart.focus.id)
        )
        model.shortcutsPage.built = [.focus]
        #expect(model.revealLanding(for: anchor) == nil)
        #expect(model.revealLanding(for: "no such row") == .wholePage)
    }

    /// The page draws the jump bar's rule where the bar does: above
    /// the part after the ruled chip's, which is the Layers card
    /// (owner 2026-11-08).
    @Test("the page rule sits where the jump bar's does")
    func pageRuleFollowsTheBar() throws {
        let ruled = ShortcutsPagePart.allCases.filter(\.ruledAbove)
        let after = ShortcutsJumpGroup.allCases.filter(\.ruledAfter)
            .compactMap { group -> ShortcutsPagePart? in
                let parts = ShortcutsPagePart.allCases
                guard let at = parts.firstIndex(of: .init(group)),
                    at + 1 < parts.count
                else { return nil }
                return parts[at + 1]
            }
        #expect(ruled == after)
        #expect(ruled == [.layers])
        let page = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            page.contains(
                "ifpart.ruledAbove{VStack(alignment:.leading,spacing:16){"
                    + "SettingsTheme.hairlineSubtle.frame(height:1)"
            )
        )
    }

    /// The page stacks the parts lazily, and every scroll into it
    /// takes the detour: the reveal, the recorder's Go to, and the
    /// whole-page fallback for a row no part is known to hold.
    @Test("the page is lazy and its scrolls reach the part first")
    func wiring() throws {
        let parts = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            parts.contains(
                "ForEach(ShortcutsPagePart.allCases){partin"
                    + "ruled(part){self.part(part,expander:expander)}"
                    + ".onAppear{"
            )
        )
        #expect(
            parts.contains(
                "ifbuildsWholePage{VStack(alignment:.leading,spacing:16,"
                    + "content:content)}else{LazyVStack("
            )
        )
        #expect(
            parts.contains(
                ".onAppear{model.shortcutsPage.built.insert(part)}"
                    + ".onDisappear{model.shortcutsPage.built.remove(part)}"
            )
        )
        let detail = try Self.source("SettingsView+Detail.swift")
        #expect(
            detail.contains(
                "ifletlanding=model.revealLanding(for:anchor){"
                    + "switchlanding{case.part(letpart):"
                    + "proxy.scrollTo(part,anchor:.top)"
                    + "case.wholePage:model.nav.shortcutsWholePage=true}"
            )
        )
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(jump.contains("ifowner==nil{buildsWholePage=true}"))
        #expect(
            jump.contains(
                "guardmodel.nav.shortcutsWholePageelse{return}"
                    + "model.nav.shortcutsWholePage=false"
                    + "buildsWholePage=true"
            )
        )
        #expect(
            parts.contains(
                "scroll(to:target,proxy:proxy,expander:expander)"
            )
        )
        #expect(
            parts.contains(
                ".onChange(of:model.nav.shortcutsWholePage){_,_in"
                    + "takeWholePageRequest()}"
            )
        )
    }

    private static func expander() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows.ofDraft(
            makeTestModel(),
            layer: KeyLayer.defaultName
        )
    }

    /// Every `SettingsControl` reachable from `value`, a drawer's own
    /// control and its children's included.
    private static func controls(in value: Any) -> [SettingsControl] {
        if let control = value as? SettingsControl { return [control] }
        if let drawer = value as? AnySettingsDrawer {
            return [drawer.control] + controls(in: drawer.childContainer)
        }
        return Mirror(reflecting: value).children.flatMap {
            controls(in: $0.value)
        }
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .filter { !$0.isWhitespace }
    }
}
