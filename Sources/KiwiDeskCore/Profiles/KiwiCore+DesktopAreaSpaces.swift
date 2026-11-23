import Foundation

/// The Desktop memory of a split screen's areas (#3517 ruling 17).
/// macOS Desktops stay per physical screen, so a Desktop switch
/// switches every area of its screen at once, each to the Space it
/// showed on that Desktop. The Desktop's own cursor
/// (`virtualSpaces`) still picks the Space the switch activates;
/// this file files and shows the screen's other areas beside it.
/// An unsplit screen files and moves nothing here.
extension KiwiCore {
    /// The main screen's departure: the Desktop's own cursor and
    /// sticky filing, then each of its areas, all read from the
    /// one switch `snapshot`.
    func rememberDeparture(
        of active: SpaceID,
        leaving: DesktopKey,
        in snapshot: DesktopSnapshot
    ) {
        rememberDeparture(of: active, leaving: leaving)
        if let main = display(forUUID: snapshot.mainUUID) {
            rememberAreaSpaces(on: main, leaving: leaving)
        }
    }

    /// The main screen's arrival: activates the Space the Desktop
    /// shows, then switches the screen's other areas with it.
    func activateArriving(
        _ target: SpaceID,
        on desktop: DesktopKey,
        in snapshot: DesktopSnapshot
    ) {
        state.workspaces.activate(target)
        guard let main = display(forUUID: snapshot.mainUUID) else {
            return
        }
        showAreaSpaces(
            on: main,
            arriving: desktop,
            in: snapshot,
            except: state.workspaces.placement(of: target)
        )
    }

    /// Files the Space each area of `display` shows under the
    /// Desktop being left, read before the switch moves any.
    func rememberAreaSpaces(
        on display: DisplayID,
        leaving desktop: DesktopKey
    ) {
        let areas = state.workspaces.placements(of: display)
        guard areas.count > 1 else { return }
        var shown: [String: SpaceID] = [:]
        for area in areas {
            guard let space = state.workspaces.activeSpace(on: area.id)
            else { continue }
            shown[area.key.description] = space
        }
        desktopMemory.areaSpaces[desktop] = shown
        desktopMemory.spaceMemoryEstablished = true
    }

    /// Shows each area of `display` but `lead` — the area the
    /// switch already moved — on the Space it showed on the
    /// arriving Desktop, else on one no other Desktop shows. An
    /// area with neither keeps what it shows.
    func showAreaSpaces(
        on display: DisplayID,
        arriving desktop: DesktopKey,
        in snapshot: DesktopSnapshot,
        except lead: PlacementID?
    ) {
        let areas = state.workspaces.placements(of: display)
        guard areas.count > 1 else { return }
        var taken = spacesShownElsewhere(excluding: desktop, in: snapshot)
        let present = snapshot.presentKeys
        for (key, shown) in desktopMemory.areaSpaces
        where key != desktop && present.contains(key) {
            taken.formUnion(shown.values)
        }
        for area in areas where area.id != lead {
            guard
                let target = areaSpaceTarget(
                    for: desktop,
                    in: area,
                    taken: taken
                )
            else { continue }
            taken.insert(target)
            state.workspaces.show(target, on: area.id)
        }
    }

    /// The Space `area` shows on `desktop`: the one filed under its
    /// own key, else one filed under a key the one resolver lands in
    /// this area (an area merged away, ruling 22), else a free one.
    private func areaSpaceTarget(
        for desktop: DesktopKey,
        in area: Placement,
        taken: Set<SpaceID>
    ) -> SpaceID? {
        let candidates = state.workspaces.spaces(on: area.id)
        let filed = desktopMemory.areaSpaces[desktop] ?? [:]
        if let own = filed[area.key.description],
            candidates.contains(own)
        {
            return own
        }
        let landed = filed.sorted { $0.key < $1.key }.first {
            candidates.contains($0.value)
                && state.workspaces.placement(
                    keyed: ScreenAreaKey(parsing: $0.key),
                    on: area.display
                ) == area.id
        }
        if let landed { return landed.value }
        let declared = currentDeclaredSpaces()
        return candidates.first {
            !taken.contains($0) && (declared?.contains($0) ?? true)
        }
    }
}
