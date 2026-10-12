import KiwiDeskCore
import SwiftUI

/// Informational banner shown when init.lua contains custom Lua
/// outside the GUI's managed vocabulary. Such code coexists
/// safely: the app saves to gui.json and never touches
/// init.lua (#55).
struct CustomLuaBanner: View {
    /// No gui.json yet, so a Save mints it and the next load takes
    /// shortcuts and rules from it instead of init.lua (#2183 ▸
    /// Ruling).
    let savingAdopts: Bool

    var body: some View {
        Label {
            Text(text)
        } icon: {
            // `ink2`, not `.blue`: a raw system hue in a
            // green-tinted window — neutral info, not a link.
            Image(systemName: "info.circle")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
    }

    private var text: String {
        savingAdopts
            ? L(
                "custom_lua_banner.adopts",
                "Your init.lua sets some settings itself. Saving "
                    + "here moves your shortcuts and rules into "
                    + "the visual editor; init.lua keeps running, "
                    + "and the app never modifies it."
            )
            : L(
                "custom_lua_banner.text",
                "Your init.lua also has custom Lua. It "
                    + "doesn\u{2019}t conflict with the "
                    + "visual editor, and the app never "
                    + "modifies init.lua."
            )
    }
}
