import Foundation

/// The empty-display heal (#1175): a connected screen is never
/// left with zero spaces. Reached from the tail of the total
/// resolve and from the one relocation that bypasses it on
/// purpose (`move_space_to_display`); `EmptyDisplayHealSeamTests`
/// pins both call sites and the ledger's writers.
extension KiwiCore {
    /// Seeds one space on every connected display left empty: a
    /// fresh number in `StarterAllocation`'s lead layout for that
    /// screen (#1018), pinned to the monitor so the next resolve
    /// keeps it. Heal, never refuse — the argument is
    /// `docs/design-decisions.md` ▸ Profiles.
    ///
    /// Idempotent per monitor through `healedSpaces`: a pin reset
    /// that did not prune (a re-dock onto the live profile's own
    /// set, a config reload) re-pins the earlier seed, lead mode
    /// re-asserted since the apply reset it, rather than minting
    /// another. Twins — two screens with one fingerprint, which a
    /// pin cannot tell apart (`docs/accepted-limitations.md`) —
    /// stand down once the seed is pinned to that fingerprint,
    /// or every resolve would mint for the twin the pin cannot
    /// reach.
    func healEmptyDisplays(mainID: DisplayID?) {
        let displays = state.workspaces.allDisplays
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        let leads = StarterAllocation.modes(
            sizes: StarterSetup.sizes(
                displays: displays,
                mainID: mainID
            )
        )
        for (position, display) in ordered.enumerated()
        where state.workspaces.spaces(on: display.id).isEmpty {
            let lead = leads[position].first ?? .bsp
            let seed: SpaceID
            switch earlierSeed(for: display.fingerprint) {
            case .heldByTwin:
                continue
            case .reusable(let earlier):
                seed = earlier
                setSpaceMode(seed, lead)
            case .absent:
                seed = nextFreeSpaceNumber()
                state.workspaces.ensureSpace(seed, mode: lead)
                healedSpaces[display.fingerprint] = seed
            }
            spacePins[seed] = display.fingerprint
            mainSpaces.remove(seed)
            state.workspaces.assign(seed, to: display.id)
            onLog(
                "heal: display '\(display.name)' had no space — "
                    + "seeded space \(seed.raw)"
            )
        }
    }

    /// Retires the ledger entries a declaration has adopted
    /// (#1175): a seed the live config now names is the user's,
    /// so the heal seeds beside it rather than re-pinning it
    /// over their choice. Every apply door calls this with the
    /// set it is about to make authoritative.
    func retireHealedSpaces(declared: Set<SpaceID>) {
        healedSpaces = healedSpaces.filter {
            !declared.contains($0.value)
        }
    }

    private enum EarlierSeed {
        case absent
        case reusable(SpaceID)
        case heldByTwin
    }

    /// The ledger's answer for one fingerprint. A seed gone from
    /// state drops its entry; one the user pinned elsewhere, or
    /// moved off by hand (`move_space_to_display`), is theirs and
    /// the screen owes a fresh one; one pinned HERE yet sitting
    /// on a screen of this same fingerprint is on the twin.
    private func earlierSeed(for fingerprint: String) -> EarlierSeed {
        guard let earlier = healedSpaces[fingerprint] else {
            return .absent
        }
        guard state.workspaces[earlier] != nil else {
            healedSpaces[fingerprint] = nil
            return .absent
        }
        switch spacePins[earlier] {
        case nil:
            return .reusable(earlier)
        case fingerprint?:
            let host = state.workspaces.display(of: earlier)
            let onTwin = state.workspaces.allDisplays.contains {
                $0.id == host && $0.fingerprint == fingerprint
            }
            return onTwin ? .heldByTwin : .absent
        default:
            return .absent
        }
    }

    /// The smallest positive number no live space is called.
    private func nextFreeSpaceNumber() -> SpaceID {
        let taken = Set(
            state.workspaces.allSpaces.compactMap { Int($0.id.raw) }
        )
        var number = 1
        while taken.contains(number) { number += 1 }
        return SpaceID(number)
    }
}
