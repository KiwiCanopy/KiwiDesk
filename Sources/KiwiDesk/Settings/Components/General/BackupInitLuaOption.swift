import AppKit
import KiwiDeskCore

/// The "Include init.lua" checkbox of the export panel (#2517)
/// and the restore confirm (#2730): off every time, greyed with
/// its reason where this Mac has no init.lua, and captioned where
/// init.lua owns the settings, since a backup without it then
/// leaves them out. A stock checkbox, so
/// focus, keyboard and VoiceOver are AppKit's.
@MainActor
final class BackupInitLuaOption: NSObject {
    let view: NSView
    private let checkbox: NSButton
    /// Called with the box's new state on each click.
    var onToggle: ((Bool) -> Void)?

    var isOn: Bool { checkbox.isEnabled && checkbox.state == .on }

    /// The export panel's box, reading this Mac's init.lua.
    convenience init(hasInitLua: Bool, luaOwned: Bool) {
        self.init(
            enabled: hasInitLua,
            note: Self.note(hasInitLua: hasInitLua, luaOwned: luaOwned)
        )
    }

    /// The restore confirm's box: enabled, with no caption, since
    /// the confirm's message says what it does.
    convenience override init() {
        self.init(enabled: true, note: nil)
    }

    private init(enabled: Bool, note: String?) {
        checkbox = NSButton(
            checkboxWithTitle: Self.label,
            target: nil,
            action: nil
        )
        checkbox.state = .off
        checkbox.isEnabled = enabled
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
        super.init()
        checkbox.target = self
        checkbox.action = #selector(toggled)
    }

    @objc private func toggled() { onToggle?(isOn) }

    #if DEBUG
        /// A user's click on the box, for the suites.
        func clickForTesting() { checkbox.performClick(nil) }
    #endif

    /// The checkbox's title, which the restore confirm's message
    /// names (#2730).
    static var label: String {
        L(
            "general.advanced.backup.export.include_init_lua",
            "Include init.lua"
        )
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
