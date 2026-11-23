import Foundation

/// The splits `init.lua`'s `set_display_areas` left stored, per
/// load, so a reload that stops declaring one makes its screen
/// whole again (#3573). Session state; a Settings or CLI write
/// never enters it.
struct LuaAreaSplits {
    /// The screens the running load named, nil outside a load.
    private(set) var declared: Set<String>?
    /// What the running load left stored per screen it named.
    private var written: [String: ScreenSplit] = [:]
    /// What the last finished load left, by screen fingerprint.
    private(set) var lastLoad: [String: ScreenSplit] = [:]

    /// Starts recording a config load.
    mutating func beginLoad() {
        declared = []
        written = [:]
    }

    /// Records a `set_display_areas` write while a load runs;
    /// `stored` is what the screen holds after it.
    mutating func note(_ fingerprint: String, _ stored: ScreenSplit?) {
        guard declared != nil else { return }
        declared?.insert(fingerprint)
        written[fingerprint] = stored
    }

    /// Follows a load's own `set_display_area_name` onto a split
    /// it declared, so the name does not hide the split from the
    /// next load's reset.
    mutating func rename(_ fingerprint: String, _ stored: ScreenSplit) {
        guard declared?.contains(fingerprint) == true else { return }
        written[fingerprint] = stored
    }

    /// Ends the load and returns the screens to make whole: each
    /// one the last load split and this one did not name, whose
    /// stored split is still the one Lua left. `kept` is false
    /// when a profile replaced the settings, which then carry no
    /// split of Lua's.
    mutating func endLoad(
        stored: [String: ScreenSplit],
        kept: Bool
    ) -> [String] {
        guard let declared else { return [] }
        defer {
            self.declared = nil
            lastLoad = kept ? written : [:]
            written = [:]
        }
        guard kept else { return [] }
        return lastLoad.keys.sorted().filter { fingerprint in
            !declared.contains(fingerprint)
                && stored[fingerprint] == lastLoad[fingerprint]
        }
    }
}
