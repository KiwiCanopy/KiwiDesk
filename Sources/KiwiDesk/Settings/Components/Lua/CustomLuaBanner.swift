import KiwiDeskCore
import SwiftUI

/// Informational banner shown when init.lua contains custom Lua
/// outside the GUI's managed vocabulary. Such code coexists
/// safely: the app saves to gui.json and never touches
/// init.lua (#55).
struct CustomLuaBanner: View {
    var body: some View {
        Label {
            Text(
                L(
                    "custom_lua_banner.text",
                    "Your init.lua also has custom Lua. It "
                        + "doesn\u{2019}t conflict with the "
                        + "visual editor, and the app never "
                        + "modifies init.lua."
                )
            )
        } icon: {
            // `ink2`, not `.blue`: a raw system hue in a
            // green-tinted window — neutral info, not a link.
            Image(systemName: "info.circle")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
    }
}
