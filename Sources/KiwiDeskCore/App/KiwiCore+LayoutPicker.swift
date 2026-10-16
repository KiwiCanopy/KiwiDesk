import AppKit

/// KiwiHub's View side (#762, #2229, #2309): its Layout line,
/// acting on the Space the pointer's screen shows —
/// on a desk of several screens the pointer is the one unambiguous
/// "this screen".
extension KiwiCore {
    /// The Space the Layout line acts on: the one shown on the
    /// screen under the pointer.
    public func layoutPickerSpace() -> SpaceID? {
        spaceUnderPointer(shelves.contextMenus.pointer())
    }

    /// The Space shown on the screen holding `point` (Cocoa), else
    /// the active one.
    func spaceUnderPointer(_ point: NSPoint) -> SpaceID? {
        let screens = ScreenList.all.compactMap { screen in
            screen.kiwiDisplayID.map { (frame: screen.frame, id: $0) }
        }
        return Self.display(at: point, among: screens)
            .flatMap { state.workspaces.activeSpace(on: $0) }
            ?? state.workspaces.activeSpace
    }

    /// Which of `screens` holds `point`, through the one lookup
    /// the pointer's other readers take.
    nonisolated static func display(
        at point: CGPoint,
        among screens: [(frame: CGRect, id: DisplayID)]
    ) -> DisplayID? {
        GeometryUtils.screenIndex(
            holding: point,
            in: screens.map(\.frame)
        ).map { screens[$0].id }
    }

    /// What the picker draws for `id`, from the Layout menu's own
    /// drift reading; nil for a Space that no longer exists.
    public func layoutPickerState(for id: SpaceID) -> LayoutPickerState? {
        guard let drift = layoutDrift(for: id) else { return nil }
        return LayoutPickerState(
            space: id,
            live: drift.live,
            drifted: drift.drifted,
            profile: profiles.currentName,
            keepArmed: drift.keepArmed
        )
    }

    /// Sets `id`'s layout as the Layout menu's row does, as user
    /// motion (#804).
    public func applyLayout(_ mode: LayoutMode, to id: SpaceID) {
        withUserMotion {
            _ = execute(
                "set_mode",
                args: [.string(id.raw), .string(mode.rawValue)]
            )
        }
    }

    /// Loads the saved profile `name` as the quick menu's row and
    /// KiwiHub's View side do, as user motion (#804, #2309).
    public func loadProfileAsUser(_ name: String) {
        withUserMotion {
            _ = execute("load_profile", args: [.string(name)])
        }
    }

    /// `id`'s live layout, whether it drifted from the profile,
    /// and whether Keep is armed — which any shown Space's drift
    /// arms, since Keep keeps every screen's layout (#1179).
    func layoutDrift(
        for id: SpaceID
    ) -> (live: LayoutMode, drifted: Bool, keepArmed: Bool)? {
        guard let space = state.workspaces[id] else { return nil }
        let shown = state.workspaces.allDisplays.compactMap {
            state.workspaces.activeSpace(on: $0.id)
        }
        let spaces = Array(Set(shown + [id]))
        let saved = savedModes(for: spaces)
        let drifted = { (space: SpaceID) in
            LayoutModeRows.drifted(
                live: self.state.workspaces[space]?.mode,
                saved: saved[space]
            )
        }
        return (
            space.mode,
            drifted(id),
            LayoutModeRows.keepArmed(drifts: spaces.map(drifted))
        )
    }
}

/// The Layout line's facts for one Space (#2229); the GUI words
/// them (#96).
public struct LayoutPickerState: Equatable, Sendable {
    public let space: SpaceID
    public let live: LayoutMode
    /// The live layout differs from the profile's.
    public let drifted: Bool
    /// The adopted profile's name; nil offers no Keep.
    public let profile: String?
    public let keepArmed: Bool

    public init(
        space: SpaceID,
        live: LayoutMode,
        drifted: Bool,
        profile: String?,
        keepArmed: Bool
    ) {
        self.space = space
        self.live = live
        self.drifted = drifted
        self.profile = profile
        self.keepArmed = keepArmed
    }
}
