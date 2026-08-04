import KiwiDeskCore

/// One instance a Monitors census key expands into (#678 Phase 3,
/// turn 13b).
///
/// Every container in this area draws a row per live thing —
/// a space chip, an orphaned pin, a connected display — so the
/// instance carries the thing's identity, which is what a guard
/// can compare and what set equality over `SettingKey` cannot
/// see.
enum MonitorsRowInstance: Hashable {
    /// One space chip, by space id — in a display card
    /// (`spacePins`) or in the follows-main tray (`mainSpaces`).
    case space(String)
    /// One pin waiting on a monitor that is not attached, by the
    /// pinned space's id.
    case orphan(String)
    /// One connected display, by fingerprint.
    case display(String)
    /// The one row in this area that is not per-instance: the
    /// banner standing in for a picture that cannot be drawn.
    case banner
}

/// One space pinned to a monitor that is not attached right now.
struct OrphanPin: Identifiable, Hashable {
    let space: SpaceID
    let fingerprint: String

    var id: String { space.raw }
}

/// Expands a Monitors census key into the rows it renders, and is
/// the same derivation the views draw from (#678 Phase 3, turn
/// 13b).
///
/// The census records settings, not rows: `spacePins` is one case
/// and puts a chip on every space that resolves to a card,
/// `fingerprints` one case and a row per connected display. That
/// is the asymmetry the Shortcuts area met first and Profiles met
/// again, and it needs the same second seam —
/// `MonitorsRowOrder` answers *where does this key sit*, this
/// answers *what does it draw*.
///
/// **The views build one of these and read it; they do not
/// re-derive beside it.** Profiles shipped the opposite twice —
/// a seam with no call sites, then call sites answering from
/// separate fixtures — so both halves here come off the same
/// instance: `rows(for:)` is written in terms of the very
/// accessors the cards, the tray, the orphan card and the drawer
/// call. `MonitorsGateWiringTests` pins each call site.
///
/// The switch is exhaustive over `MonitorsKey` on purpose: a key
/// added to the census fails to compile here until it is given an
/// expansion.
struct MonitorsFamilyRows {
    /// The spaces the config declares, in its own order.
    let spaces: [SpaceID]
    /// Spaces set to follow whichever display is main.
    let mainSpaces: Set<SpaceID>
    /// Each space's resolved placement, from the model's one
    /// `resolutions()` pass — the runtime's own precedence (pin →
    /// main → positional default), never re-implemented here.
    let resolutions: [SpaceID: SpaceResolution]
    /// The pins as saved, which is what an ORPHANED pin is read
    /// from: a resolution can only name a display that exists.
    let pins: [SpaceID: String]
    /// The connected displays.
    let displays: [Display]

    /// The displays in the order the drawer and the chip menus
    /// list them: left to right across the desk, so the reading
    /// order matches the picture above them.
    ///
    /// Sorted on THREE keys, because `sorted` is not stable and
    /// x alone ties on any vertically stacked pair — a list that
    /// reordered itself between renders would move the menu item
    /// under the pointer.
    var orderedDisplays: [Display] {
        displays.sorted {
            (
                $0.frame.minX, -$0.frame.minY, $0.id.raw
            ) < (
                $1.frame.minX, -$1.frame.minY, $1.id.raw
            )
        }
    }

    /// Whether two connected displays are indistinguishable to
    /// KiwiDesk.
    ///
    /// `Display.fingerprint` is `name:WxH`, so a pair of the same
    /// model at the same resolution — the commonest twin-monitor
    /// desk — is ONE identity. Every pin, every card's chips and
    /// the main badge key off that fingerprint, so the picture
    /// draws the same spaces on both cards. The page says so
    /// rather than letting it read as a bug; the real fix is a
    /// display identity Core can tell apart, which is not this
    /// turn's to make.
    var hasAmbiguousDisplays: Bool {
        Set(displays.map(\.fingerprint)).count < displays.count
    }

    /// The chips one display's card holds: spaces pinned to it,
    /// and spaces the positional default places there. Spaces
    /// that follow main live in the tray instead, so every space
    /// appears exactly once (#53: there is no unassigned list).
    func chips(on fingerprint: String) -> [SpaceAssignment] {
        spaces.compactMap { space in
            guard !mainSpaces.contains(space) else { return nil }
            switch resolutions[space] {
            case .pinned(let pinned) where pinned == fingerprint:
                return SpaceAssignment(space: space, kind: .pinned)
            case .auto(let auto) where auto == fingerprint:
                return SpaceAssignment(space: space, kind: .auto)
            default:
                return nil
            }
        }
    }

    /// The chips in the dashed follows-main tray.
    var trayChips: [SpaceID] {
        spaces.filter { mainSpaces.contains($0) }
    }

    /// Pins waiting on hardware that is not attached. Read from
    /// the SAVED pins rather than from a resolution, which can
    /// only ever name a display that exists — the user's intent
    /// has to stay visible and clearable while its monitor is
    /// away.
    var orphans: [OrphanPin] {
        let connected = Set(displays.map(\.fingerprint))
        return
            pins
            .filter { !connected.contains($0.value) }
            .map { OrphanPin(space: $0.key, fingerprint: $0.value) }
            .sorted { $0.space.raw < $1.space.raw }
    }

    /// Every space that draws a chip in some card — the union of
    /// what the cards hold, derived from `chips(on:)` rather than
    /// beside it, so the census expansion and the screen cannot
    /// disagree about which spaces are carded.
    var cardedSpaces: [SpaceAssignment] {
        orderedDisplays.flatMap { chips(on: $0.fingerprint) }
    }

    func rows(for key: SettingKey) -> [MonitorsRowInstance]? {
        guard case .monitors(let family) = key else { return nil }
        return rows(for: family)
    }

    private func rows(
        for family: MonitorsKey
    ) -> [MonitorsRowInstance]? {
        switch family {
        case .spacePins:
            return cardedSpaces.map {
                MonitorsRowInstance.space($0.space.raw)
            }
        case .mainSpaces:
            return trayChips.map {
                MonitorsRowInstance.space($0.raw)
            }
        case .orphanPinClear:
            return orphans.map {
                MonitorsRowInstance.orphan($0.space.raw)
            }
        case .fingerprints:
            return orderedDisplays.map {
                MonitorsRowInstance.display($0.fingerprint)
            }
        case .placementUnavailable:
            // Exactly one row, always — whether it is on screen
            // is its GATE's answer, not this seam's. Expanding to
            // nil while the picture is drawable would make the
            // banner indistinguishable from a family that lost
            // its rows.
            return [.banner]
        }
    }
}
