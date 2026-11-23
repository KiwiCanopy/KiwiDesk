import AppKit

/// KiwiHub's "here" (#762, #2229, #2309, #3572): the area under the
/// pointer — on a desk of several screens, or a screen split into
/// areas, the pointer is the one unambiguous "here". Both sides
/// read it: the View side's Layout line and the Windows side's
/// rows and Move here.
extension KiwiCore {
    /// The Space the Layout line acts on: the one `area` shows —
    /// KiwiHub's "here", read once as the panel opens.
    public func layoutPickerSpace(in area: PlacementID?) -> SpaceID? {
        moveHereSpace(in: area)
    }

    /// The area under the pointer — an unsplit screen's one area —
    /// that KiwiHub opens over and files Move here into (#2791,
    /// #3572); nil off every screen. Judged on the screens state
    /// holds, as every area reader is.
    public func jumpArea() -> PlacementID? {
        let point = shelves.contextMenus.pointer()
        let screens = state.workspaces.allDisplays.map {
            (frame: $0.frame, id: $0.id)
        }
        guard let display = Self.display(at: point, among: screens) else {
            return nil
        }
        return pointerPlacement(
            atAX: GeometryUtils.axPoint(point),
            on: display
        )
    }

    /// `area`'s usable rect in Cocoa coordinates, from the one
    /// per-placement frame reader (`placementFrames`), which KiwiHub
    /// centres in (#3572 ruling 1); nil for a screen not connected.
    public func visibleFrame(of area: PlacementID) -> CGRect? {
        placementFrames().first { $0.id == area }.map {
            GeometryUtils.flip(
                $0.frame,
                primaryHeight: GeometryUtils.primaryHeight
            )
        }
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

    /// Saves the live arrangement as `name` as KiwiHub's Save as
    /// New Profile… does (#2359), as user motion; whether it
    /// landed.
    public func saveProfileAsUser(_ name: String) -> Bool {
        withUserMotion {
            execute("save_profile", args: [.string(name)]).isSuccess
        }
    }

    /// `id`'s live layout, whether it drifted from the profile,
    /// and whether Keep is armed — which any shown Space's drift
    /// arms, since Keep keeps every screen's layout (#1179).
    func layoutDrift(
        for id: SpaceID
    ) -> (live: LayoutMode, drifted: Bool, keepArmed: Bool)? {
        guard let space = state.workspaces[id] else { return nil }
        // Every area's shown Space (#3517).
        let spaces = Array(state.workspaces.visibleSpaces.union([id]))
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
