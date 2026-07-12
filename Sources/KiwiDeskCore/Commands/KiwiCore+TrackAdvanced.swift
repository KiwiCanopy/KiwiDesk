import Foundation

/// The advanced-track gate (#181): track's default configuration
/// is the simple 1D columns/rows layout, and one global flag —
/// `set_track_advanced`, default OFF — unlocks the three 2D
/// authoring surfaces (`move_to_track` joining a track,
/// `new_window = focused_track`, and the `auto_tracks`-off cap
/// merge). The engine is untouched in both states; the gate
/// lives at the command/tiling boundary, never in `Layouts` or
/// `State` math.
///
/// Ownership: the flag is a **global** (a `GuiConfig` sidecar
/// field, `track_advanced`, beside `app_rules`), never a
/// `track.*` setting — that namespace serializes into profiles,
/// and a per-profile authoring gate would make the
/// inert-keybinding semantics circular. Lua-only users set it in
/// `init.lua` via `KiwiDesk.set_track_advanced(true)`.
extension KiwiCore {
    /// The single predicate authority every consumer asks —
    /// command guards, the resolution clamp, keybinding
    /// registration, and the GUI (through its `GuiConfig`
    /// binding). The stored bit lives on `StateCoordinator` so
    /// state-side insertion and the tiling engine read the same
    /// storage; nothing else may keep a copy.
    public var isTrackAdvanced: Bool {
        state.trackAdvanced
    }

    /// The track params every command-path reader uses (#181):
    /// per-space resolution first, then the advanced-track
    /// clamp (`TrackParams.gated`). `TilingSettings` stays
    /// flag-unaware; route new readers through here, never
    /// through `resolvedTrack` directly.
    func effectiveTrack(for space: SpaceID) -> TrackParams {
        tiler.settings.resolvedTrack(for: space)
            .gated(advanced: isTrackAdvanced)
    }

    /// The reject message the gated actions share
    /// (`move_to_track`, `track.swap`): actions push state
    /// toward 2D — exactly what the gate prevents — so unlike
    /// the accept-and-store setters they fail loudly, with the
    /// pointer to the switch.
    static let trackAdvancedHint =
        "joining tracks is part of advanced track — enable "
        + "with set_track_advanced(true) or in Settings"

    /// `KiwiDesk.set_track_advanced(bool)`. Setters like
    /// `track.set_auto_tracks` keep accepting while the flag is
    /// off (rejecting them would be data loss in command form —
    /// profiles decode the stored values anyway); only the
    /// resolved view is clamped. Flipping the flag re-registers
    /// keybindings (inert rows come and go with it) and forces
    /// a retile: OFF drops a read-time cap merge back to the
    /// marker partition, ON restores it — an explicit config
    /// apply, so the ±2 pt tolerance must not swallow it.
    func setTrackAdvanced(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        guard state.trackAdvanced != on else { return .ok() }
        state.trackAdvanced = on
        refreshStructuredKeybindings()
        retile(force: true)
        return .ok()
    }
}

/// The catalog keybinding bodies the gate makes inert (#181).
/// While advanced track is off these exact rows are skipped at
/// structured registration (no Carbon hotkey), hidden from the
/// rendered sections, excluded from conflict detection, and
/// silently stealable — but never pruned from the stored modes,
/// so re-enabling restores every binding not reused since.
///
/// Only byte-exact catalog bodies are gated: a custom Lua row
/// that merely *contains* a gated call keeps registering (its
/// other actions must fire; the gated command itself rejects
/// with the pointer). The GUI catalog authors these same
/// strings — pinned by a parity test so neither side drifts.
public enum TrackAdvancedBindings {
    public static let gatedLua: Set<String> = Set(
        ["left", "down", "up", "right"].flatMap {
            [
                "KiwiDesk.move_to_track(\"\($0)\")",
                "track.swap(\"\($0)\")",
            ]
        }
    )

    public static func isGated(_ lua: String) -> Bool {
        gatedLua.contains(lua)
    }
}
