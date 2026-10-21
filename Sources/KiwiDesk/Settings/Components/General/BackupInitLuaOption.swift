import AppKit
import KiwiDeskCore

/// The export panel's "Include init.lua" checkbox (#2517): off
/// every time, greyed with its reason where this Mac has no
/// init.lua, and captioned where init.lua owns the settings, since
/// a backup without it then leaves them out. A stock checkbox, so
/// focus, keyboard and VoiceOver are AppKit's.
@MainActor
final class BackupInitLuaOption {
    let view: NSView
    private let checkbox: NSButton

    var isOn: Bool { checkbox.isEnabled && checkbox.state == .on }

    init(hasInitLua: Bool, luaOwned: Bool) {
        checkbox = NSButton(
            checkboxWithTitle: L(
                "general.advanced.backup.export.include_init_lua",
                "Include init.lua"
            ),
            target: nil,
            action: nil
        )
        checkbox.state = .off
        checkbox.isEnabled = hasInitLua
        let note = Self.note(hasInitLua: hasInitLua, luaOwned: luaOwned)
        let stack = NSStackView(views: [checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        if let note {
            let caption = NSTextField(wrappingLabelWithString: note)
            caption.font = .systemFont(
                ofSize: NSFont.smallSystemFontSize
            )
            caption.preferredMaxLayoutWidth = 360
            stack.addArrangedSubview(caption)
            checkbox.setAccessibilityHelp(note)
        }
        stack.edgeInsets = NSEdgeInsets(
            top: 8,
            left: 16,
            bottom: 8,
            right: 16
        )
        view = stack
    }

    /// Why the box is greyed, or what leaving it off costs.
    private static func note(hasInitLua: Bool, luaOwned: Bool) -> String? {
        if !hasInitLua {
            return L(
                "general.advanced.backup.export.no_init_lua",
                "This Mac has no init.lua."
            )
        }
        if luaOwned {
            return L(
                "general.advanced.backup.export.lua_owned",
                "Your settings come from init.lua, so a backup "
                    + "without it leaves them out."
            )
        }
        return nil
    }
}
