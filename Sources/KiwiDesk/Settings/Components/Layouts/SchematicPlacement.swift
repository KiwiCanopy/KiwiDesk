import KiwiDeskCore

/// Where a schematic's incoming window opens.
///
/// Five schematics draw the dense `+` tile at the slot the spawn
/// placement chooses, and each carried its own copy of
/// `Space.insert(_:placement:)`'s four-arm switch (#702). This
/// asks the engine instead — it splices a window into a real
/// `Space` and reports where it landed — so the rule has one
/// implementation and a change to how KiwiDesk places a new
/// window moves every preview with it.
///
/// Reaching for the engine rather than a sixth copy is the whole
/// point: AGENTS.md §2.4 would let a small duplication stand, but
/// `.claude/rules/parity-tests.md` stops paying for it past two
/// mirrors, and a call is cheaper here than either a mirror or
/// the parity test a mirror would owe.
/// Two suites hold it, and they fail apart:
/// `LayoutSchematicPlacementTests` holds each schematic to the
/// promise its frame makes a reader — stated independently of
/// both the engine and this helper — and
/// `LayoutSchematicPlacementScanTests` reds on the next file to
/// carry a second copy of the rule.
/// `LayoutSchematicTrackEngineTests` pins the one mode with an
/// engine of its own, `Space.insertIntoTrack`.
enum SchematicPlacement {
    /// The incoming window's slot among `count` established
    /// windows whose focused one sits at index `focus`, and the
    /// slot that focused window ends up in.
    ///
    /// Both, because a splice at or before the focus pushes the
    /// focused window one slot along. A schematic that keys its
    /// tiles by window id gets that for free and reads only
    /// `incoming`; one that renders a fixed run of slots
    /// (Track's focused track) has to be told, and drawing the
    /// focus at its pre-splice index is exactly #702. Neither
    /// number is computed here — both are read back off the
    /// space the engine mutated.
    ///
    /// The answer is an **index**, not the resulting order, so a
    /// caller re-performs the insert itself. That is faithful
    /// while `insert` is a positional splice and would go quietly
    /// wrong the day it also moves `focused`, refuses, or
    /// reorders — the id-keyed callers' guards read both ids back
    /// out of the array they built, which is what would notice.
    ///
    /// `focus` must index `count`. Out of range it would fall
    /// back to the last window and hand back a plausible wrong
    /// answer, which is #702's own shape one level down; every
    /// caller's focus reference is pinned present by
    /// `LayoutSchematicPlacementTests`, and the assertion below
    /// is the second net.
    static func splice(
        _ placement: SpawnPlacement,
        count: Int,
        focus: Int
    ) -> (incoming: Int, focus: Int) {
        let established = (0..<max(0, count)).map {
            WindowID(UInt32($0))
        }
        assert(
            established.indices.contains(focus),
            "focus \(focus) outside \(count) established windows"
        )
        let incoming = WindowID(UInt32(max(0, count)))
        var space = Space(
            id: "schematic",
            windows: established,
            focused: established.indices.contains(focus)
                ? established[focus] : established.last
        )
        space.insert(incoming, placement: placement)
        let landed = space.windows.firstIndex(of: incoming) ?? 0
        let settled =
            space.focused.flatMap {
                space.windows.firstIndex(of: $0)
            } ?? landed
        return (landed, settled)
    }
}
