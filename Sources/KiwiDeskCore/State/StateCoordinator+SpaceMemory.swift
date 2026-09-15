import Foundation

/// Space memory accessors and provenance tracking (`StateCoordinator`, #1010).
extension StateCoordinator {
    /// Tracks origin and provenance of remembered window space associations
    /// (`StateSnapshot.adopt`, #1010).
    enum SpaceMemory: Sendable, Equatable {
        /// Window departure observed by destroy fold.
        case departed(SpaceID)
        /// Filed from session snapshot before window discovery.
        case restored(SpaceID)

        var space: SpaceID {
            switch self {
            case .departed(let space), .restored(let space):
                return space
            }
        }
    }

    /// What a departed window takes back on its return (#1207,
    /// #1387): the slot it held and the break it had — one value,
    /// so every ender and the re-key carry both or neither.
    struct DepartedSlot: Sendable, Equatable {
        var rank: Int
        /// Re-derived at each departure of the Space: a handed
        /// break stays handed while a break is held and ends when
        /// none is. Residue: a holder given a break of its OWN
        /// while its head is away reads as handed until that head
        /// returns and takes it, or it departs and drops it.
        var trackBreak: Space.BreakProvenance
        /// The member `handTrackBreakToSuccessor` gave this
        /// window's break to at its departure — the one holder a
        /// promotion or a return may take it from. Set on a head
        /// alone: a handed break is never handed on (ruling,
        /// #1387).
        var handedTo: WindowID?

        init(
            rank: Int,
            trackBreak: Space.BreakProvenance = .member,
            handedTo: WindowID? = nil
        ) {
            self.rank = rank
            self.trackBreak = trackBreak
            self.handedTo = handedTo
        }
    }

    /// Records restored space association for untracked window
    /// (`rememberedSpaces`, #1010).
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = .restored(space)
    }

    /// Records the rank of every member of `space` as `id` departs
    /// it (#1207): each one's index today, raised past every
    /// sibling that already departed this space ahead of it — a
    /// burst folds one window at a time, so the index alone would
    /// read 0 for each. The stayers are re-ranked too, so a member
    /// that never departs (a carried sticky) ranks by where it
    /// sits rather than by a rank from an earlier departure.
    mutating func rememberDepartedSlot(
        of id: WindowID,
        in space: SpaceID
    ) {
        guard let members = workspaces[space]?.windows,
            members.contains(id)
        else { return }
        let heads = workspaces[space]?.trackBreaks ?? []
        let departed = departedSlots.filter { entry in
            windows[entry.key] == nil
                && rememberedSpaces[entry.key] == .departed(space)
        }.values.map(\.rank).sorted()
        for (index, member) in members.enumerated() {
            var rank = index
            for sibling in departed where sibling <= rank {
                rank += 1
            }
            // A handed break stays handed while it is held; a
            // break gone from the live set ends the mark.
            let held = heads.contains(member)
            let handed =
                held && departedSlots[member]?.trackBreak == .handed
            departedSlots[member] = DepartedSlot(
                rank: rank,
                trackBreak: !held ? .member : handed ? .handed : .head
            )
        }
        // The removal about to follow hands `id`'s OWN break on;
        // the record names the holder and marks it before a later
        // departure re-reads it.
        guard departedSlots[id]?.trackBreak == .head else {
            dropHandedBreak(of: id)
            return
        }
        if let successor = workspaces[space]?.handOffTarget(of: id) {
            departedSlots[id]?.handedTo = successor
            departedSlots[successor]?.trackBreak = .handed
        }
    }

    /// Re-files a departure the destroy fold just recorded under
    /// the Space an explicit Desktop-move target named (#1150).
    /// A writer of `rememberedSpaces` OUTSIDE a fold — `refileAway`
    /// is the other (#1248) — and safe as one because it runs in
    /// the same synchronous arm as that fold, before any reader:
    /// `forgetGoneWindow` reads nothing of it, and the away
    /// ledger files the NATIVE Space.
    /// The `.departed` memory takes the name and the slot rank is
    /// dropped, a rank meaning something only in the Space it was
    /// taken in; rankless, the create fold's spawn placement is
    /// the authority for where the return lands, and the away
    /// merge (`withAwayMembers`) previews it LAST, which may
    /// differ. False, and a no-op, for anything but a `.departed`
    /// record — a minimize, a close, a `.restored` filing.
    @discardableResult
    mutating func redirectDeparture(
        of id: WindowID,
        to space: SpaceID
    ) -> Bool {
        guard case .departed? = rememberedSpaces[id] else {
            return false
        }
        promoteHandedSuccessor(of: id)
        rememberedSpaces[id] = .departed(space)
        departedSlots[id] = nil
        return true
    }

    /// Re-points an AWAY window's remembered Space at the one the
    /// incoming profile records for it (#1248), keeping the kind:
    /// a watched departure stays `.departed`, a boot-seeded
    /// `.restored` filing stays restored — the population most
    /// likely to be away across a switch is the one a restart
    /// seeded, so it cannot be the case this skips.
    ///
    /// A same-space call is REFUSED rather than made a silent
    /// no-op: the rank goes with the move (it means something
    /// only in the Space it was taken in), so redirecting a
    /// window to where it already is would spend its #1207 return
    /// slot for nothing, on every switch.
    ///
    /// `redirectDeparture` is the other writer and stays separate:
    /// it answers #1150's explicit Desktop-move target, is
    /// `.departed`-only by ruling, and runs in the destroy fold's
    /// own arm.
    @discardableResult
    mutating func refileAway(
        of id: WindowID,
        to space: SpaceID
    ) -> Bool {
        guard let current = rememberedSpaces[id],
            current.space != space
        else { return false }
        promoteHandedSuccessor(of: id)
        switch current {
        case .departed: rememberedSpaces[id] = .departed(space)
        case .restored: rememberedSpaces[id] = .restored(space)
        }
        departedSlots[id] = nil
        return true
    }

    /// A handed break is never handed on (ruling, #1387): a window
    /// leaving the row while recorded as holding one drops it, so
    /// `Space.remove` finds nothing to pass. Every removal of a
    /// live window that is not a hand-off of its own calls this
    /// ahead of `workspaces.remove` — the destroy fold and the
    /// app-exit fold.
    mutating func dropHandedBreak(of id: WindowID) {
        guard departedSlots[id]?.trackBreak == .handed,
            let space = workspaces.space(of: id)
        else { return }
        workspaces.withSpace(space) { $0.dropTrackBreak(of: id) }
    }

    /// A head gone for good makes its hand-off permanent (#1387):
    /// the holder its record names, while still recorded handed,
    /// becomes a head of its own — or that holder's next return
    /// would leave the break on the member behind it. Every ender
    /// of a `.head` record calls this ahead of dropping it
    /// (state-and-layout.md's census); a hide or a Desktop
    /// departure keeps the hand-off revocable.
    mutating func promoteHandedSuccessor(of id: WindowID) {
        guard let slot = departedSlots[id], slot.trackBreak == .head,
            let holder = slot.handedTo,
            departedSlots[holder]?.trackBreak == .handed
        else { return }
        departedSlots[holder]?.trackBreak = .head
    }

    /// The member of `space` holding `id`'s handed break now —
    /// nil where the holder was promoted, is not back yet, or
    /// dropped it at its own departure.
    func handedHolder(of id: WindowID, in space: SpaceID) -> WindowID? {
        guard let holder = departedSlots[id]?.handedTo,
            departedSlots[holder]?.trackBreak == .handed,
            workspaces[space]?.trackBreaks.contains(holder) == true
        else { return nil }
        return holder
    }

    /// Retires a window closed while away (#1146): the ledger
    /// entry and the two #1207 records it was read with.
    mutating func forgetAway(_ id: WindowID) {
        promoteHandedSuccessor(of: id)
        awayWindows[id] = nil
        rememberedSpaces[id] = nil
        restoredFrames[id] = nil
        departedSlots[id] = nil
    }

    /// Clears all remembered space associations (`CGWindowID`, #634).
    public mutating func forgetRememberedSpaces() {
        rememberedSpaces = [:]
        restoredFrames = [:]
        departedSlots = [:]
        awayWindows = [:]
    }

    /// Retrieves remembered space identifier for untracked window.
    func rememberedSpace(of id: WindowID) -> SpaceID? {
        rememberedSpaces[id]?.space
    }
}
