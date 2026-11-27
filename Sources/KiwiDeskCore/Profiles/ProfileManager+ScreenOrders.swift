import Foundation

/// The session's three answers to which connected screen holds which
/// number (#3647), beside the stored sets: the user's renumber, the
/// fit rule's order, and the order an apply installs while it runs.
/// `KiwiCore.liveScreenOrder` reads them in the reverse order.
struct ScreenOrderSession: Equatable {
    /// A session renumber and its profile (lane 2b).
    var override: SessionScreenOrder?
    /// The order the fit rule chose for a profile's setup (lane 3),
    /// kept until the override's clears or another setup.
    var fitted: SessionScreenOrder?
    /// The order an apply installs, set by its two doors alone.
    var inFlight: ScreenOrder?

    /// A delete of `profile` drops what was its.
    mutating func forget(_ profile: String) {
        if override?.profile == profile { override = nil }
        if fitted?.profile == profile { fitted = nil }
    }

    /// A rename carries what was `old`'s to `new`.
    mutating func rename(_ old: String, to new: String) {
        if override?.profile == old { override?.profile = new }
        if fitted?.profile == old { fitted?.profile = new }
    }
}

extension ProfileManager {
    /// A session renumber and its profile (nil: none live), read
    /// through `KiwiCore+SessionScreenOrder`.
    var sessionScreenOrder: SessionScreenOrder? {
        screenOrders.override
    }

    func setSessionScreenOrder(_ order: ScreenOrder?, for name: String?) {
        screenOrders.override = order.map {
            .init(profile: name, order: $0)
        }
    }

    /// The order an apply installs while it runs.
    var screenOrderInFlight: ScreenOrder? {
        get { screenOrders.inFlight }
        set { screenOrders.inFlight = newValue }
    }
}
