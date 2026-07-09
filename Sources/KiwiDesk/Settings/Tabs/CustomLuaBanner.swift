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
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
