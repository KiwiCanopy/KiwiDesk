import Foundation

/// The total space→display resolution (#36) — split from
/// `KiwiCore+ProfileResolution.swift` at the §2.1 ceiling along
/// the seam that file's own header already named: applying a
/// profile is one subject, deciding which screen each Space lays
/// out on is another.
extension KiwiCore {
    /// Total space→display resolution (#36): every space gets
    /// a screen via the shared `SpacePlacement` precedence,
    /// written into workspace state so the GUI renders the
    /// resolved mapping.
    func resolveSpaceDisplays(
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) {
        resolveSpaceDisplays(
            of: state.workspaces.allSpaces.map(\.id),
            mainID: mainID
        )
    }

    /// The resolve for `spaces` alone, then the heal and the float
    /// re-anchor as the total one runs them. A door that changes
    /// no screen — a pin, a delete, a retire — places only what it
    /// touched, so a `move_space_to_display` holds until a screen
    /// change re-resolves every Space (#3578).
    func resolveSpaceDisplays(
        of spaces: [SpaceID],
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) {
        let displays = state.workspaces.allDisplays
        // The one unresolvable state; resolve() below can then
        // never return nil.
        guard !displays.isEmpty else { return }
        let assignment = composedAssignment(displays, mainID: mainID)
        let previous = Dictionary(
            uniqueKeysWithValues: state.workspaces.allSpaces.compactMap {
                space in
                state.workspaces.display(of: space.id).map {
                    (space.id, $0)
                }
            }
        )
        for space in spaces where state.workspaces[space] != nil {
            guard
                let display = resolvedDisplay(
                    of: space,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            else { continue }
            state.workspaces.assign(
                space,
                to: areaPlacement(of: space, on: display)
            )
        }
        // A display the resolve left with no space is healed
        // HERE (#1175), before relocation is judged: a reused
        // seed the precedence sent to main and the heal sent
        // back has not moved, and re-anchoring its floats to
        // main would strand them.
        healEmptyDisplays(mainID: mainID)
        // Every space-relocation path funnels through this
        // resolve — monitor re-dock, profile apply, config
        // reload, a pin, a heal — so the cross-display float
        // re-anchor lives HERE (#444 review), not per verb. A
        // first-ever assignment (`previous == nil`, boot) is not
        // a relocation.
        for space in state.workspaces.allSpaces {
            guard let before = previous[space.id],
                let after = state.workspaces.display(of: space.id),
                before != after
            else { continue }
            reanchorFloats(of: space.id)
        }
    }

    /// Places each Space with no screen — one a command or a
    /// restart's replay created by an undeclared id — where the
    /// resolve's precedence would, touching no other Space (#1994).
    /// Without one it has no chip, no `activeSpace(on:)` and no
    /// slide. Adding a Space empties no screen and relocates none,
    /// so neither the heal nor the float re-anchor is owed. True
    /// when it placed one.
    @discardableResult
    func placeUnplacedSpaces(
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) -> Bool {
        let displays = state.workspaces.allDisplays
        let unplaced = state.workspaces.allSpaces.map(\.id).filter {
            state.workspaces.display(of: $0) == nil
        }
        guard !displays.isEmpty, !unplaced.isEmpty else { return false }
        let assignment = composedAssignment(displays, mainID: mainID)
        for space in unplaced {
            guard
                let display = resolvedDisplay(
                    of: space,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            else { continue }
            state.workspaces.assign(
                space,
                to: areaPlacement(of: space, on: display)
            )
        }
        return true
    }

    /// The screen `space` lays out on: its assignment, else where
    /// the precedence would place it — asked before a Space named
    /// by an undeclared id exists (#1994). Nil with no screen.
    func landingDisplay(
        of space: SpaceID,
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) -> DisplayID? {
        if let display = state.workspaces.display(of: space) {
            return display
        }
        let displays = state.workspaces.allDisplays
        return resolvedDisplay(
            of: space,
            displays: displays,
            mainID: mainID,
            assignment: composedAssignment(displays, mainID: mainID)
        )
    }

    private func composedAssignment(
        _ displays: [Display],
        mainID: DisplayID
    ) -> [SpaceID: DisplayID] {
        SpacePlacement.numberedPlan(
            displays: displays,
            mainID: mainID
        )
    }

    /// The area of `display` that `space` lays out in (#3517): the
    /// area its pin names, else the area it already holds on that
    /// screen, else the screen's area 0. A pin naming an area
    /// the split no longer has falls back to area 0 (ruling 22).
    func areaPlacement(
        of space: SpaceID,
        on display: DisplayID
    ) -> PlacementID {
        let ws = state.workspaces
        if let pin = spacePins[space],
            let named = ws.placement(
                keyed: ScreenAreaKey(parsing: pin),
                on: display
            )
        {
            return named
        }
        if let held = ws.placement(of: space), held.display == display,
            ws[placement: held] != nil
        {
            return held
        }
        return ws.leadPlacement(of: display)
            ?? PlacementID(display: display, area: 0)
    }

    /// The one copy of the `SpacePlacement` call every placement
    /// takes; nil only with no screen.
    private func resolvedDisplay(
        of space: SpaceID,
        displays: [Display],
        mainID: DisplayID,
        assignment: [SpaceID: DisplayID]
    ) -> DisplayID? {
        SpacePlacement.resolve(
            space: space,
            pins: spacePins,
            mainSpaces: mainSpaces,
            displays: displays,
            mainID: mainID,
            assignment: assignment
        )?.display.id
    }
}
