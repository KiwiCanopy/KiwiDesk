import Testing

@testable import KiwiDesk

/// Which catalog drawers stand childless, and why (#277 fill,
/// #1250). Split from `SettingsCatalogTests` at the file
/// ceiling. A drawer declared without children hides whatever
/// the census places behind it from a search hit — the hit
/// lands on the destination root with the drawer shut — so a
/// childless declaration is a conscious ruling recorded here,
/// never a default a new drawer inherits.
@Suite("Settings catalog drawers")
struct SettingsCatalogDrawerTests {
    /// Every drawer the catalog declares with `SettingsNoChildren`,
    /// by id, each with the reason it carries none. Fail-shut in
    /// both directions: a drawer landing childless joins with its
    /// reason, and one that gains children leaves.
    private let childless: Set<String> = [
        // Per-Desktop binding rows carry dynamic labels no static
        // index can name (#678 turn 13a).
        "desktops.title",
        // Hardware presets for unconnected setups: the rows are
        // the presets themselves, a browse rather than a search.
        "presets.other_setups",
        // Monitor fingerprints are per-display readouts, labelled
        // by the display.
        "monitors.advanced.title",
        // The Desktop and Track families' rows are `.dynamic`
        // (#1125, #1440); the door is the one searchable name.
        "shortcuts.desktops.focus",
        "shortcuts.desktops.move",
        "shortcuts.tracks.move",
        // Raw Lua bindings: rows are the user's own bindings.
        "shortcuts.advanced.title",
        // Advanced Colours' two "More colors" drawers are ruled
        // OUT of the #277 fill: colour selection is a browse
        // interaction, not a name search (the issue's tier
        // audit, 2026-08-27).
        "space_bar/colors.more",
        "app_bar/colors.more",
    ]

    /// The declared set matches the register above — derived
    /// by reflection over every destination container, so a
    /// drawer whose children are `SettingsNoChildren` cannot
    /// land unrecorded, and a stale entry cannot linger.
    @Test("childless drawers are pinned with their reason")
    func childlessDrawersArePinned() {
        var found: Set<String> = []
        for destination in SettingsDestination.allCases {
            let container = SettingsCatalog.container(of: destination)
            for child in Mirror(reflecting: container).children {
                guard let drawer = child.value as? AnySettingsDrawer
                else { continue }
                if drawer.childContainer is SettingsNoChildren {
                    found.insert(drawer.control.id)
                }
            }
        }
        #expect(!found.isEmpty)
        #expect(
            found == childless,
            Comment(
                rawValue:
                    "unrecorded: "
                    + found.subtracting(childless).sorted()
                    .joined(separator: ", ")
                    + " | stale: "
                    + childless.subtracting(found).sorted()
                    .joined(separator: ", ")
            )
        )
    }
}
