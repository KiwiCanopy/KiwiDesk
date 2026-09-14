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
        let assignment =
            ProfileComposition.compose(
                displays: displays,
                mainID: mainID
            )?.assignment ?? [:]
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
                let resolved = SpacePlacement.resolve(
                    space: space.id,
                    pins: spacePins,
                    mainSpaces: mainSpaces,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            else { continue }
            state.workspaces.assign(
                space.id,
                to: resolved.display.id
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
}
