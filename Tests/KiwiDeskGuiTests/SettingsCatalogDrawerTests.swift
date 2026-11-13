import Testing

@testable import KiwiDesk

/// Which catalog drawers stand childless, and why (#277 fill,
/// #1250). A drawer declared without children hides whatever
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
        // Monitor fingerprints are per-display readouts, labelled
        // by the display.
        "monitors.advanced.title",
        // The Desktop moves' and Track families' rows are
        // `.dynamic` (#2655, #1440); the door is a searchable name.
        "shortcuts.desktops.move",
        "shortcuts.tracks.move",
        // Profiles per macOS Desktop: one binding row per Desktop,
        // `.dynamic`, since the switch cue left for Shortcuts ▸
        // macOS Desktops (#2655).
        "desktops.title",
        // Maximize's screen shapes not connected (#3062): each row
        // is a shape, and its cells are the card's own columns.
        "layout_defaults.maximize.other_shapes",
        // Raw Lua bindings: rows are the user's own bindings.
        "shortcuts.advanced.title",
        // Key sequences (#1871): rows are the user's own sequences.
        "shortcuts.section.key_sequences",
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
