import Foundation

/// Live-apply for keybinding edits (#123 Part 1).
///
/// The recorder is an input device: a successfully committed
/// recording must work the moment it is recorded, not after a
/// Save. This entry point re-registers the running hotkeys
/// from the GUI's edited (unsaved) base mode set — the same
/// live-mutate-no-persist shape as `set_mode`. Nothing is
/// written to disk: the dashboard's dirty flag and its footer
/// keep their exact meaning ("the file hasn't caught up"),
/// and Save / Revert stay the only bridges to disk.
extension KiwiCore {
    /// Re-registers all hotkeys from `modes` — the edited BASE
    /// mode set — resolved through the active profile's sparse
    /// override: exactly the registration a Save + config
    /// reload would produce, with no file writes. Passing
    /// `nil` re-registers from the saved sidecar instead — the
    /// Revert / discard direction, flushing any live-applied
    /// recording back out (no ghost hotkeys).
    ///
    /// GUI-managed only (Lua-owned configs keep Lua
    /// authoritative), and a no-op before the first
    /// `loadConfig` (no VM yet) — the same guards as
    /// `applyStructuredConfig`.
    ///
    /// The active key mode is preserved when it survives the
    /// edit — unlike profile applies, which deliberately reset
    /// to default because the mode set changes with the
    /// profile: re-recording one shortcut must not silently
    /// drop the user out of the mode they are in.
    ///
    /// Registration failures (system-reserved combos) land in
    /// `keys.activationFailures` for the caller's feedback.
    public func liveApplyKeybindings(modes: [KeyMode]?) {
        guard isGuiManaged, let lua = keys.lua else { return }
        guard
            let base = modes ?? loadStructuredConfig()?.modes
        else { return }
        let active = keys.currentMode
        applyStructuredKeybindings(
            modes: base,
            profile: activeProfileOverrides()?.modes,
            lua: lua
        )
        if active != KeybindingManager.defaultMode,
            keys.definedModes.contains(active)
        {
            keys.switchMode(active)
        }
    }
}
