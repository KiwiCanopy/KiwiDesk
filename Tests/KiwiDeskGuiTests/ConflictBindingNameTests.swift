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

    @Test("another profile's Space is named though this page lacks it")
    func foreignSpaceIsNamed() {
        LocalizationManager.shared.select("en")
        let config = config(spaces: ["1"])
        let rival = KeyBinding(
            combo: "alt+7",
            lua: "KiwiDesk.focus_space(\"7\")"
        )
        #expect(
            KeybindingCatalog.localizedName(of: rival, config: config)
                == rival.lua
        )
        let foreign = KeybindingCatalog.localizedName(
            of: rival,
            config: config,
            foreign: true
        )
        #expect(foreign != rival.lua)
        #expect(foreign.contains("7"))
    }
}
