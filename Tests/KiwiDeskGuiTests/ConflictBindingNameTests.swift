import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A conflict names each side the way its row does (#2116): Core
/// hands over the bindings, and the GUI names a label-less one by
/// its catalog command, else its Lua — never by its combo, which
/// Core used to pick.
@Suite("Conflict sides are named by the GUI (#2116)")
@MainActor
struct ConflictBindingNameTests {
    private func config(spaces: [String]) -> GuiConfig {
        var config = GuiConfig()
        config.spaces = spaces.map { SpaceID($0) }
        return config
    }

    @Test("a label-less duplicate is named by its command")
    func labelLessSideIsNamed() {
        LocalizationManager.shared.select("en")
        let config = config(spaces: ["3"])
        let mine = KeyBinding(
            combo: "alt+3",
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: "Focus window left"
        )
        let rival = KeyBinding(
            combo: "alt+3",
            lua: "KiwiDesk.focus_space(\"3\")"
        )
        let sentence = ConflictText.reading(
            for: mine,
            in: [mine, rival],
            config: config,
            disabled: []
        )?.sentence
        let named = KeybindingCatalog.localizedName(
            of: rival,
            config: config
        )
        #expect(named != rival.lua)
        #expect(sentence?.contains(named) == true)
        #expect(sentence?.contains("alt+3") == false)
    }

    /// The door widens its roster by what the binding itself
    /// names, labelled or not, so another profile's seeded row and
    /// its Lua twin both read their command's name (#2116).
    @Test("another profile's Space is named, labelled or not")
    func foreignSpaceIsNamed() {
        LocalizationManager.shared.select("en")
        let config = config(spaces: ["1"])
        let bare = KeyBinding(
            combo: "alt+7",
            lua: "KiwiDesk.focus_space(\"7\")"
        )
        let labelled = KeyBinding(
            combo: "alt+7",
            lua: "KiwiDesk.focus_space(\"7\")",
            kind: .navigation,
            label: "Go to Space 7"
        )
        LocalizationManager.shared.select("de")
        let named = KeybindingCatalog.localizedName(of: bare, config: config)
        #expect(named != bare.lua)
        #expect(
            KeybindingCatalog.localizedName(of: labelled, config: config)
                == named
        )
        #expect(named != "Go to Space 7")
        LocalizationManager.shared.select("en")
    }

    /// The banner names a label-less side the same way as the
    /// tooltip.
    @Test("the banner names a label-less side by its command")
    func bannerNamesLabelLessSide() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        model.config.spaces = [SpaceID("3")]
        model.config.layers = [
            KeyLayer(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+3",
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: "Focus window left"
                    ),
                    KeyBinding(
                        combo: "alt+3",
                        lua: "KiwiDesk.focus_space(\"3\")"
                    ),
                ]
            )
        ]
        model.warnIfAnyConflict()
        let banner = model.keybindingWarning ?? ""
        #expect(!banner.isEmpty)
        #expect(!banner.contains("alt+3"))
        #expect(!banner.contains("focus_space"))
    }
}
