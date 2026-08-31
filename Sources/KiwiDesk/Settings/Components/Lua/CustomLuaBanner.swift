import KiwiDeskCore
import SwiftUI

/// Informational banner shown when init.lua contains custom Lua (#55).
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
            Image(systemName: "info.circle")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
    }
}
