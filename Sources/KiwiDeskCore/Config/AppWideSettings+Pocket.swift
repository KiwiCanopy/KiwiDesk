import Foundation

extension AppWideSettings {
    /// `gui.json`'s `pocket` group (#2678) — additive, as
    /// `desktop`; capacity never shipped per profile.
    struct Pocket: Codable, Equatable {
        var capacity: PocketCapacity?
    }

    var pocket: Pocket { Pocket(capacity: pocketCapacity) }
}
