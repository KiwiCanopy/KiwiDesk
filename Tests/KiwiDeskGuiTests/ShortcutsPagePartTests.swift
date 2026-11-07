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
    /// included, resolves to the part that draws it.
    @Test("every catalog control names its part")
    func catalogControlsHaveParts() {
        let expander = Self.expander()
        let controls = Self.controls(in: SettingsCatalog.shortcuts)
        #expect(controls.count > 20)
        for control in controls {
            #expect(
                ShortcutsPagePart.owner(of: control.id, expander: expander)
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
                ShortcutsPagePart.owner(of: label, expander: expander)
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
            ShortcutsPagePart.owner(of: focus.lua, expander: expander)
                == .focus
        )
        #expect(
            ShortcutsPagePart.owner(of: "no such row", expander: expander)
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

    /// The page stacks the parts lazily, and every scroll into it
    /// takes the detour: the reveal, the recorder's Go to, and the
    /// whole-page fallback for a row no part is known to hold.
    @Test("the page is lazy and its scrolls reach the part first")
    func wiring() throws {
        let parts = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            parts.contains(
                "ForEach(ShortcutsPagePart.allCases){partin"
                    + "self.part(part,expander:expander)}"
            )
        )
        #expect(
            parts.contains(
                "ifbuildsWholePage{VStack(alignment:.leading,spacing:16,"
                    + "content:content)}else{LazyVStack("
            )
        )
        let detail = try Self.source("SettingsView+Detail.swift")
        #expect(
            detail.contains(
                "ifletpart=model.revealPart(for:anchor){"
                    + "proxy.scrollTo(part,anchor:.top)"
            )
        )
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(
            jump.contains(
                "letowner=ShortcutsPagePart.owner(of:target,"
                    + "expander:expander)ifowner==nil{buildsWholePage=true}"
            )
        )
        let section = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            section.contains(
                "scroll(to:target,proxy:proxy,expander:expander)"
            )
        )
        #expect(
            section.contains(
                ".onChange(of:model.nav.revealTarget){_,targetin"
                    + "buildWholePage(revealing:target)}"
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
