import KiwiDeskCore
import SwiftUI

/// Core's verdict on one row's Lua, and the Lua it judged: a body
/// edited since shows no verdict until it is committed (#2574).
struct LuaVerdict: Equatable {
    let lua: String
    let problem: String?
}

/// A Lua binding that does not compile says so on its row, glyph
/// and text, from Core's compile check (#2574 ▸ Ruling).
extension AdvancedLuaGroup {
    /// Asks Core about the row's committed Lua.
    func judge(_ id: UUID) {
        guard let lua = bindings.first(where: { $0.id == id })?.lua
        else { return }
        verdicts[id] = LuaVerdict(
            lua: lua,
            problem: model.core.shortcutLuaProblem(lua)
        )
    }

    /// The problem Core found in the Lua the row holds now, if any.
    func problem(_ binding: KeyBinding) -> String? {
        guard let verdict = verdicts[binding.id], verdict.lua == binding.lua
        else { return nil }
        return verdict.problem
    }

    @ViewBuilder
    func deadWarning(_ binding: KeyBinding) -> some View {
        if let problem = problem(binding) {
            Label {
                Text(
                    L(
                        "shortcuts.lua.dead",
                        "This shortcut does nothing: its Lua doesn't "
                            + "compile. %1$@",
                        problem
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.warningInk)
        }
    }
}
