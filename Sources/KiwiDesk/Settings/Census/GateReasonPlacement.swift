/// Which greyed rows owe their reason INLINE (#815).
///
/// A dim says an answer exists; without a reason it withholds
/// it, and the reason reached `.help()` only — a hover string,
/// which needs a pointer. But the answer is not "caption every
/// greyed row": several of these greys are ordinary states (an
/// auto-sized grid, an App Bar off in a layout), a `GreyOut`
/// inside a `ForEach` would stamp the same sentence under every
/// child, and the tree already answers "why" three other ways.
/// So the three channels, in the order a reader meets them:
///
/// 1. a **block** gate keeps its live `?` anchor outside the
///    dimmed subtree (#527, `GreyOutAnchorTests`);
/// 2. a row whose **cause is legible on this surface** — the
///    gating control sits in the same container, or a standing
///    caption already names it — needs nothing more; the hover
///    string stays for the pointer user;
/// 3. a row gated from **another destination** takes the live
///    `?` whose sentence names where to go (`docs/ui-patterns.md`
///    ▸ a remote control-scoped gate; Advanced Colours is
///    entirely this);
/// 4. everything else owes the sentence INLINE, because there
///    is nothing on screen to connect the dim to.
///
/// This type answers 2 vs 3 from the census rather than from a
/// hand-kept list, which is the half a future row cannot
/// forget: a new gated row inherits the answer the day it is
/// declared. `GateReasonPlacementTests` pins it against the
/// sites that already draw a reason inline.
enum GateReasonPlacement {
    /// Which channel carries a gated row's reason. Three, not
    /// two — the middle one is why a first cut of this
    /// derivation claimed twenty-four rows owed an inline
    /// sentence when three do.
    enum Channel: Hashable {
        /// The gating control is in the same container, drawn at
        /// rest, or the condition is legible on the surface.
        /// Adjacency answers "why"; the hover string stays for
        /// the pointer user.
        case adjacent
        /// The gating control lives on ANOTHER destination.
        /// `docs/ui-patterns.md` already rules this one: a live
        /// `?` on the nearest label above the dimmed rows, whose
        /// sentence names the destination to go to (Advanced
        /// Colours is the case that forced it, and every gate on
        /// that page is this).
        case remote
        /// Same page, no adjacency, nothing else to look at —
        /// the case neither of the other two covers, and the one
        /// #815 is about.
        case inline
    }

    /// Whether this row's gate needs its reason drawn inline.
    ///
    /// Container gates are NOT this type's business — they have
    /// the `?` anchor — so a row is judged on its own `gate:`
    /// alone.
    /// The `placement` seam defaults to the census itself, so
    /// the wiring point is PRODUCTION's and a test overriding it
    /// is the exception rather than the only caller.
    static func owesInlineReason(
        _ key: SettingKey,
        placement: (SettingKey) -> SettingPlacement = {
            $0.placement
        }
    ) -> Bool {
        channel(key, placement: placement) == .inline
    }

    /// The channel this row's reason travels by, or nil when the
    /// row carries no gate of its own.
    static func channel(
        _ key: SettingKey,
        placement: (SettingKey) -> SettingPlacement = {
            $0.placement
        }
    ) -> Channel? {
        let row = placement(key)
        guard let gate = row.gate, let area = row.area else {
            return nil
        }
        switch gate {
        case .setting, .anyOf:
            let owners = gate.settings.map(placement)
            if owners.contains(where: {
                $0.area == area && $0.container == row.container
                    && $0.tier.visibilityRank
                        <= row.tier.visibilityRank
            }) {
                return .adjacent
            }
            // Every owner on another page: the `?` anchor names
            // where to go, and an inline sentence here would be
            // a second copy of it. A row gated from BOTH places
            // counts as remote too — the anchor is drawn either
            // way, and it is the channel that can point.
            if owners.allSatisfy({ $0.area != area }) {
                return .remote
            }
            return .inline
        case .runtime(let condition):
            // A SURFACING condition dims nothing — it decides
            // whether the row is drawn — so it has no reason to
            // carry and no channel. Answered by the condition's
            // own declared flavour rather than by folding
            // "surfaces" into "legible", which made one name
            // answer two questions and would have inherited
            // `.adjacent` for a condition that later became a
            // grey (architect review, 2026-08-12).
            guard condition.greys else { return nil }
            return condition.causeIsOnSurface ? .adjacent : .inline
        case .runtimeAnyOf(let conditions):
            guard conditions.contains(where: \.greys) else {
                return nil
            }
            // Every GREYING arm has to be legible: a row dead for
            // a reason the reader cannot see is not rescued by
            // another reason they can.
            return conditions.filter(\.greys)
                .allSatisfy(\.causeIsOnSurface)
                ? .adjacent : .inline
        }
    }
}

extension SettingTier {
    /// How far the reader has to go to see a row at this tier —
    /// lower is nearer. Adjacency compares the gating row
    /// against the gated one rather than testing either alone:
    /// what matters is that the cause is on screen WHENEVER the
    /// dimmed row is, and two rows inside one disclosure satisfy
    /// that while neither draws at rest. Testing the owner for
    /// `atRest` instead claimed the App Bar's whole Show-more
    /// block owed inline sentences, which is the caption-per-row
    /// outcome this design refuses.
    var visibilityRank: Int {
        switch self {
        case .atRest: return 0
        // NOT `atRest`'s peer, against the first cut: an
        // `.immediate` row is the one whose gate says the thing
        // already exists, and while that gate withholds it the
        // row is not on screen at all — so a row gated BY one
        // cannot claim its cause is beside it (architect
        // review, 2026-08-12).
        case .immediate, .showMore: return 1
        case .luaOnly, .internalOnly, .outsideSettings:
            // No surface at all, so it can never be the thing a
            // reader looks at.
            return .max
        }
    }
}

extension SettingRuntimeGate {
    /// Whether this condition GREYS a row or decides whether it
    /// is drawn at all. Two different questions, and folding
    /// them into one predicate hid the second: five conditions
    /// answered "the cause is on the surface" when what they
    /// meant was "there is no dimmed control here", so a
    /// condition that later became a grey would have inherited
    /// "owes nothing" with nothing red.
    ///
    /// The flavour is already stated in prose on each case in
    /// `SettingGate.swift`; this is the machine-readable half.
    var greys: Bool {
        switch self {
        case .perEdgeValuesDiffer, .editingStoredProfile,
            .displaysHaveSeparateSpaces, .screenCountMismatch,
            .loginItemServiceStatus, .autoStartLoginOff,
            .spaceHasNoOverrides, .reduceMotion:
            return true
        case .orphanPinsExist, .monitorsDisconnected,
            .paletteGlowPairing, .luaImportAvailable,
            .layersExist, .liquidGlassUnavailable:
            // Presence, not greying: these decide whether a row
            // or card is drawn.
            return false
        }
    }

    /// Whether the thing this condition names is visible on the
    /// surface the gated row is on. Only meaningful where
    /// `greys` — a row that is not drawn has no reason to give.
    ///
    /// Exhaustive on purpose — no `default` — so a new condition
    /// has to answer rather than inherit a guess, and each arm
    /// names WHAT the reader sees, since that is the claim being
    /// made and it is the part that goes stale when a surface
    /// moves.
    var causeIsOnSurface: Bool {
        switch self {
        case .perEdgeValuesDiffer:
            // The per-edge drawer sits directly below the
            // master it disagrees with — the reader repairs it
            // there.
            return true
        case .spaceHasNoOverrides:
            // Every row above the reset action reads "follows
            // the defaults", which IS the condition.
            return true
        case .reduceMotion, .loginItemServiceStatus,
            .autoStartLoginOff, .displaysHaveSeparateSpaces:
            // System state, with nothing in this window to look
            // at. The rows gated on the middle two already draw
            // their reason inline today, which is what
            // `GateReasonPlacementTests` checks this answer
            // against.
            return false
        case .editingStoredProfile, .screenCountMismatch:
            // Which profile is being edited, and which monitors
            // a preset wants, are the page's own subject — the
            // edit target rides the header chip and the preset
            // cards name their screen count.
            return true
        case .orphanPinsExist, .monitorsDisconnected,
            .paletteGlowPairing, .luaImportAvailable,
            .layersExist, .liquidGlassUnavailable:
            // Presence conditions: `greys` is false, so this
            // answer is never read. Stated rather than defaulted
            // so the switch stays exhaustive by hand.
            return true
        }
    }
}
