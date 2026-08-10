import KiwiDeskCore
import SwiftUI

/// Informational banner shown in the visual editor when
/// `init.lua` contains custom Lua that does NOT touch the
/// GUI's managed vocabulary (app rules, keybindings, etc.).
/// Such code coexists safely — the app saves to `gui.json`
/// and never touches `init.lua` (#55), so there is no
/// conflict with what the visual editor owns.
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
            // green-tinted window, and the note is neutral
            // information, not a link (dark pass).
            Image(systemName: "info.circle")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
    }
}
