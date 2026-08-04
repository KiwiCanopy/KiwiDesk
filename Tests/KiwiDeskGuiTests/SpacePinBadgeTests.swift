import Testing

@testable import KiwiDesk

/// The space row's display-pin badge decision (#678 Phase 3, turn
/// 8a). Pure over its inputs, so the three cases are pinned here
/// rather than inferred from the row view.
@Suite("Space pin badge")
struct SpacePinBadgeTests {
    private let connected: Set<String> = [
        "LG:2560x1440", "Built-in:1512x982",
    ]

    private func name(_ fingerprint: String) -> String {
        // The GUI's `monitorName`: known fingerprints resolve to a
        // human name, an unknown one falls back to itself.
        [
            "LG:2560x1440": "LG 27",
            "Built-in:1512x982": "Built-in",
        ][fingerprint] ?? fingerprint
    }

    @Test("no pin shows no badge")
    func unpinned() {
        #expect(
            SpacePinBadge.resolve(
                pin: nil,
                connectedFingerprints: connected,
                name: name
            ) == SpacePinBadge.none
        )
        // An empty fingerprint is unpinned too — the sparse map
        // stores no entry, but a defensive empty string must not
        // read as a live pin.
        #expect(
            SpacePinBadge.resolve(
                pin: "",
                connectedFingerprints: connected,
                name: name
            ) == SpacePinBadge.none
        )
    }

    @Test("a pin to an attached display names it")
    func pinnedNamesTheDisplay() {
        #expect(
            SpacePinBadge.resolve(
                pin: "LG:2560x1440",
                connectedFingerprints: connected,
                name: name
            ) == .pinned(displayName: "LG 27")
        )
    }

    @Test("a pin to a detached display reads offline")
    func offlineWhenDetached() {
        #expect(
            SpacePinBadge.resolve(
                pin: "Dell:3840x2160",
                connectedFingerprints: connected,
                name: name
            ) == .offline
        )
    }
}
