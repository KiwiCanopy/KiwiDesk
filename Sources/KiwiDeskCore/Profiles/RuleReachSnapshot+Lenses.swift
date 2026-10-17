import Foundation

/// The lens family over every profile's `lens_reach` (#2103 rulings
/// 38, 39): the Settings lens page's renames, deletes and "Applies
/// to" picks, laid over the stored marks so one `saveRuleReach`
/// writes them with the rest of the Save. A profile no mark names
/// reaches the lens; a built-in has no file and reaches every lens.
extension RuleReachSnapshot {
    /// The readable profiles, in stored order.
    public var lensProfiles: [String] { appRules.profiles }

    /// Renames every mark at once — `map` is stored name → new
    /// name — through a placeholder per lens, so a chain or a swap
    /// cannot merge two lenses' marks.
    public mutating func renameLenses(_ map: [String: String]) {
        let renames = map.filter { !$0.key.isEmpty }
            .sorted { $0.key < $1.key }
        guard !renames.isEmpty else { return }
        for profile in lensReach.keys {
            var marks: [String: Bool]? = lensReach[profile]
            for (at, rename) in renames.enumerated() {
                marks = VisionLens.reach(
                    marks,
                    renaming: rename.key,
                    to: Self.placeholder(at)
                )
            }
            for (at, rename) in renames.enumerated() {
                marks = VisionLens.reach(
                    marks,
                    renaming: Self.placeholder(at),
                    to: rename.value
                )
            }
            lensReach[profile] = marks ?? [:]
        }
    }

    /// Clears every profile's mark of each deleted lens.
    public mutating func deleteLenses(_ names: [String]) {
        for profile in lensReach.keys {
            var marks: [String: Bool]? = lensReach[profile]
            for name in names {
                marks = VisionLens.reach(marks, deleting: name)
            }
            lensReach[profile] = marks ?? [:]
        }
    }

    /// The readable profiles `lens` reaches.
    public func profilesReaching(_ lens: String) -> Set<String> {
        let key = VisionLens.reachKey(lens)
        return Set(
            lensProfiles.filter { lensReach[$0]?[key] != false }
        )
    }

    /// `lens` reaches exactly `reached` of the readable profiles: a
    /// profile in it drops its mark, any other is marked left out.
    public mutating func setLensReach(_ lens: String, reached: Set<String>) {
        let key = VisionLens.reachKey(lens)
        for profile in lensProfiles {
            var marks = lensReach[profile] ?? [:]
            marks[key] = reached.contains(profile) ? nil : false
            lensReach[profile] = marks
        }
    }

    private static func placeholder(_ at: Int) -> String {
        "\u{1F}\(at)"
    }
}
