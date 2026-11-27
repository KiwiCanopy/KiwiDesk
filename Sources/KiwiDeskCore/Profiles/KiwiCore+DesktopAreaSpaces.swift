import CoreGraphics
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
        // The screen the Desktop left lives on, read by its stamp:
        // a number re-read in this reading may name another one.
        let left =
            leaving.isIdentity
            ? snapshot.space(for: leaving)?.displayUUID : nil
        if let screen = display(forUUID: left ?? snapshot.mainUUID) {
            rememberAreaSpaces(on: screen, leaving: leaving)
        }
    }

    /// A secondary screen's departure: the Space it showed under
    /// the Desktop's cursor, then each of its areas.
    func rememberLeaving(
        _ display: DisplayID,
        leaving desktop: DesktopKey
    ) {
        if let shown = state.workspaces.activeSpace(on: display) {
            rememberVirtualSpace(shown, leaving: desktop)
        }
        rememberAreaSpaces(on: display, leaving: desktop)
    }

    /// A secondary screen's arrival: shows the Space the Desktop
    /// shows, then switches the screen's other areas with it.
    func showArriving(
        _ target: SpaceID,
        on display: DisplayID,
        as desktop: DesktopKey,
        in snapshot: DesktopSnapshot
    ) {
        state.workspaces.show(target, on: display)
        showAreaSpaces(
            on: display,
            arriving: desktop,
            in: snapshot,
            except: state.workspaces.placement(of: target)
        )
    }

    /// Whether `key`, an `N#id` slot, names an area of Screen N's
    /// stored split — connected or not, so an unplugged screen's
    /// memory stays live for its return. An unsplit number holds no
    /// area here.
    func isStoredArea(_ key: String) -> Bool {
        guard let slot = ScreenSlotKey(parsing: key) else { return false }
        return tiler.settings.displayAreas[number: slot.number]?.areas
            .contains { $0.id == slot.areaID } ?? false
    }

    /// Moves the areas' memory a merge absorbed onto its survivor,
    /// read off the shares before and after the change.
    func remapAreaSpaces(
        from old: [String: ScreenShares],
        to new: [String: ScreenShares]
    ) {
        for remap in Self.areaRemaps(from: old, to: new) {
            for (desktop, var shown) in desktopMemory.areaSpaces {
                remap.move(in: &shown)
                desktopMemory.areaSpaces[desktop] = shown
            }
        }
    }

    /// The merges between two sets of shares, number by number: an
    /// area id the new split lacks went into the area now covering
    /// its middle. A number left unsplit keeps its entries dormant.
    static func areaRemaps(
        from old: [String: ScreenShares],
        to new: [String: ScreenShares]
    ) -> [ScreenAreaRemap] {
        old.sorted { $0.key < $1.key }.flatMap { key, before in
            guard let after = new[key],
                let number = ScreenSlotKey(parsing: key)?.number
            else { return [ScreenAreaRemap]() }
            let kept = Set(after.areas.map(\.id))
            return before.areas.filter { !kept.contains($0.id) }
                .compactMap { area -> ScreenAreaRemap? in
                    let middle = CGPoint(x: area.rect.midX, y: area.rect.midY)
                    guard
                        let survivor = after.areas.first(where: {
                            $0.rect.contains(middle)
                        }),
                        let vanished = ScreenSlotKey(
                            number: number,
                            areaID: area.id
                        ),
                        let into = ScreenSlotKey(
                            number: number,
                            areaID: survivor.id
                        )
                    else { return nil }
                    return ScreenAreaRemap(vanished: vanished, survivor: into)
                }
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
        let order = liveScreenOrder
        for area in areas {
            guard let space = state.workspaces.activeSpace(on: area.id),
                let slot = order.slot(of: area.key)
            else { continue }
            shown[slot.description] = space
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
        for (area, target) in areaSpaceTargets(
            on: display,
            arriving: desktop,
            in: snapshot,
            except: lead
        ) {
            state.workspaces.show(target, on: area)
        }
    }

    /// The Space each area of a split `display` but `lead` shows on
    /// arriving at `desktop`, as `showAreaSpaces` switches them —
    /// the one answer the switch and KiwiHub's hidden cards read
    /// (#3572). Empty on an unsplit screen.
    func areaSpaceTargets(
        on display: DisplayID,
        arriving desktop: DesktopKey,
        in snapshot: DesktopSnapshot,
        except lead: PlacementID?
    ) -> [(PlacementID, SpaceID)] {
        let areas = state.workspaces.placements(of: display)
        guard areas.count > 1 else { return [] }
        var taken = spacesShownElsewhere(excluding: desktop, in: snapshot)
        var targets: [(PlacementID, SpaceID)] = []
        for area in areas where area.id != lead {
            guard
                let target = areaSpaceTarget(
                    for: desktop,
                    in: area,
                    taken: taken
                )
            else { continue }
            taken.insert(target)
            targets.append((area.id, target))
        }
        return targets
    }

    /// The Space `area` shows on `desktop`: the one filed under its
    /// own key, else any filed Space that now lays out in this area,
    /// else a free one. A filed Space wins over `taken`, as the
    /// cursor's does. The middle step is how a merge reaches this
    /// memory (ruling 22): the merged-away area's Space follows its
    /// pin into the survivor, and an area id is never minted twice
    /// (ruling 21), so a stale key names no other area; the next
    /// departure files the Desktop afresh.
    private func areaSpaceTarget(
        for desktop: DesktopKey,
        in area: Placement,
        taken: Set<SpaceID>
    ) -> SpaceID? {
        let candidates = state.workspaces.spaces(on: area.id)
        let filed = desktopMemory.areaSpaces[desktop] ?? [:]
        if let own = liveScreenOrder.slot(of: area.key)
            .flatMap({ filed[$0.description] }),
            candidates.contains(own)
        {
            return own
        }
        let moved = filed.sorted { $0.key < $1.key }.first {
            candidates.contains($0.value)
        }
        if let moved { return moved.value }
        let declared = currentDeclaredSpaces()
        return candidates.first {
            !taken.contains($0) && (declared?.contains($0) ?? true)
        }
    }
}
