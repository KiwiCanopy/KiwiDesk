import Testing

@testable import KiwiDeskCore

/// **A raised window the public list does not show yet is judged on
/// its level** (#3443). Zephium re-shows one reused launcher at
/// layer 5; for a moment AX lists it while the public window list
/// answers nothing for it, and SkyLight's level already reads 5
/// (device, 2026-11-18). The fixture's server snapshot finds no
/// window for these ids, so it is that moment.
extension ArrivalAdoptionTests {
    @Test("a raised arrival floats on its level, not the list's nil")
    func raisedArrivalFloats() {
        let (loop, box, _, listing) = makeLoop()
        listing.layers = [arrivals[0]: 5]
        loop.reconcileOffMain(pid: pid, app: ref)
        let raised = box.created.first { $0.id == arrivals[0] }
        let standard = box.created.first { $0.id == arrivals[1] }
        #expect(raised?.isRaisedLayer == true)
        #expect(raised?.isFloating == true)
        #expect(loop.detectedFloating[arrivals[0]] == .floats(.raisedLayer))
        // The normal-layer sibling still tiles.
        #expect(standard?.isFloating == false)
    }
}
