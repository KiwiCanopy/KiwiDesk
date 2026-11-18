import Testing

@testable import KiwiDeskCore

/// **A window AX lists before the public window list does is judged
/// on its level** (#3443). Zephium re-shows one reused launcher at
/// layer 5, and for a moment AX lists it while the public list
/// holds no entry and SkyLight's level already reads 5 (device,
/// 2026-11-18). The fixture's server snapshot lists none of its
/// ids, so every arrival here is in that moment.
extension ArrivalAdoptionTests {
    /// Raised and unlisted: its alpha and bounds are unread, so the
    /// #309 helper rule cannot judge it yet, and it tiled on the
    /// nil read as layer 0.
    @Test("a raised arrival the public list omits waits for a retrack")
    func raisedArrivalWaits() {
        let (loop, box, _, listing) = makeLoop()
        listing.layers = [arrivals[0]: 5]
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.created.map(\.id) == [arrivals[1]])
        #expect(loop.elements[pid]?[arrivals[0]] == nil)
        #expect(loop.transientRetried[pid]?.contains(arrivals[0]) == true)
    }

    /// Normal and unlisted: the level agrees with the reading, so
    /// the read's verdict stands and the main actor asks nothing.
    @Test("an unlisted normal-layer arrival keeps the read's verdict")
    func unlistedNormalArrivalKeepsTheRead() {
        let (loop, box, _, listing) = makeLoop()
        for id in arrivals { listing.layers[id] = 0 }
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.created.map(\.id) == arrivals)
        #expect(box.applyCalls == 0, "\(box.applyCalls) main-actor AX calls")
    }

    /// Zephium re-shows one launcher id, so a retry spent on its
    /// first order-in would leave every later one to whatever
    /// reconcile came (#675's one retry per id).
    @Test("adopting a window returns its transient retry")
    func adoptionReturnsTheRetry() {
        let (loop, box, _, _) = makeLoop()
        loop.transientRetried[pid] = [arrivals[0]]
        loop.reconcileOffMain(pid: pid, app: ref)
        #expect(box.created.map(\.id) == arrivals)
        #expect(loop.transientRetried[pid]?.contains(arrivals[0]) == false)
    }
}
