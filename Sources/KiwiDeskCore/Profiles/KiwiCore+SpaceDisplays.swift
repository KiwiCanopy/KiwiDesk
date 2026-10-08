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
        for space in state.workspaces.allSpaces {
            guard
                let display = resolvedDisplay(
                    of: space.id,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            else { continue }
            state.workspaces.assign(space.id, to: display)
        }
        // A display the resolve left with no space is healed
        // HERE (#1175), before relocation is judged: a reused
        // seed the precedence sent to main and the heal sent
        // back has not moved, and re-anchoring its floats to
        // main would strand them.
        healEmptyDisplays(mainID: mainID)
        // Every space-relocation path funnels through this
        // resolve — monitor re-dock, profile apply, config
        // reload, pin displacement — so the cross-display float
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
            state.workspaces.assign(space, to: display)
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
        ProfileComposition.compose(
            displays: displays,
            mainID: mainID
        )?.assignment ?? [:]
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
