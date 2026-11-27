import Foundation

/// The splits `init.lua`'s `set_display_areas` left stored, per
/// load and keyed by screen number (#3647 ▸ lane 3), so a reload
/// that stops declaring one makes its screen
/// whole again (#3573). Session state; a Settings or CLI write
/// never enters it.
struct LuaAreaSplits {
    /// The screens the running load named, nil outside a load.
    private(set) var declared: Set<String>?
    /// What the running load left stored per screen it named.
    private var written: [String: ScreenShares] = [:]
    /// What the last finished load left, by screen number.
    private(set) var lastLoad: [String: ScreenShares] = [:]
    /// The screens a finished load named while its held splits wait
    /// for the first screen report (#3640); its settle waits too.
    private var awaiting: Set<String>?
    /// Set while the drain replays a call a load held, so its write
    /// joins that load's record.
    var replaying = false

    /// Whether a config load is being recorded.
    var isRecording: Bool { declared != nil }

    /// Starts recording a config load. A load still waiting on held
    /// splits ends as finished: the reset dropped what it held.
    mutating func beginLoad() {
        if awaiting != nil { lastLoad = written }
        awaiting = nil
        declared = []
        written = [:]
    }

    /// Ends a load whose `init.lua` failed: it resets nothing,
    /// and what it did split joins the last load's record.
    mutating func abandonLoad() {
        guard declared != nil else { return }
        lastLoad.merge(written) { $1 }
        declared = nil
        written = [:]
    }

    /// Records a `set_display_areas` write while a load runs;
    /// `stored` is what the screen holds after it.
    mutating func note(_ number: String, _ stored: ScreenShares?) {
        if declared != nil {
            declared?.insert(number)
            written[number] = stored
        } else if replaying, awaiting != nil {
            awaiting?.insert(number)
            written[number] = stored
        } else if replaying {
            lastLoad[number] = stored  // an abandoned load's
        }
    }

    /// Follows a `set_display_area_name` onto a split Lua made —
    /// the running load's, or the last one's while `old` is still
    /// what it left — so a name never takes the split from Lua.
    mutating func rename(
        _ number: String,
        from old: ScreenShares,
        to stored: ScreenShares
    ) {
        if declared?.contains(number) == true
            || awaiting?.contains(number) == true
        {
            written[number] = stored
        } else if lastLoad[number] == old {
            lastLoad[number] = stored
        }
    }

    /// Ends the load and returns the screens to make whole: each
    /// one the last load split and this one did not name, whose
    /// stored split is still the one Lua left. `kept` is false
    /// when a profile replaced the settings, which then carry no
    /// split of Lua's. A kept load `holding` a split for the first
    /// screen report keeps its record open and settles in
    /// `endHeld`, so a screen it names by number is never made
    /// whole first.
    mutating func endLoad(
        stored: [String: ScreenShares],
        kept: Bool,
        holding: Bool
    ) -> [String] {
        guard let declared else { return [] }
        self.declared = nil
        if kept, holding {
            awaiting = declared
            return []
        }
        defer {
            lastLoad = kept ? written : [:]
            written = [:]
        }
        guard kept else { return [] }
        return dropped(declared: declared, stored: stored)
    }

    /// Ends a load whose held splits the drain stored, as `endLoad`
    /// would have; nothing while no load waits.
    mutating func endHeld(stored: [String: ScreenShares]) -> [String] {
        guard let declared = awaiting else { return [] }
        awaiting = nil
        defer {
            lastLoad = written
            written = [:]
        }
        return dropped(declared: declared, stored: stored)
    }

    private func dropped(
        declared: Set<String>,
        stored: [String: ScreenShares]
    ) -> [String] {
        lastLoad.keys.sorted().filter { number in
            !declared.contains(number)
                && stored[number] == lastLoad[number]
        }
    }
}
