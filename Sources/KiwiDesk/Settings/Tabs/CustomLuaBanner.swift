import SwiftUI

/// Informational banner shown in the visual editor when
/// `init.lua` contains custom Lua outside the managed block
/// that does NOT touch the GUI's managed vocabulary (app rules,
/// keybindings, etc.). Such code coexists safely — it is
/// preserved verbatim on every save and has no conflict with
/// what the visual editor writes.
struct CustomLuaBanner: View {
    var body: some View {
        Label {
            Text(
                "This config also has custom Lua outside "
                    + "the managed block. It doesn\u{2019}t "
                    + "conflict with the visual editor and is "
                    + "preserved on every save."
            )
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
