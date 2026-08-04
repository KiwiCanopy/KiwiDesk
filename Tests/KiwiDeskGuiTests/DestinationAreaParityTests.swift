import Testing

@testable import KiwiDesk

/// The destination ↔ census-area bridge (#678 turn 9). The two
/// enums are hand-kept mirrors — navigation identity on one
/// side, placement vocabulary on the other — and Home joins
/// them (a card is offered per AREA rule and opens a
/// DESTINATION), so past two mirrors the map owes a
/// forget-proof parity test (parity-tests.md).
@Suite("Destination ↔ area parity")
struct DestinationAreaParityTests {
    /// Round-tripping every destination through its area comes
    /// back to itself — with `init(area:)` exhaustive over
    /// `SettingsArea`, this makes the map a bijection: a new
    /// case on either side fails to compile or fails here.
    @Test("the map is a bijection")
    func bijection() {
        for destination in SettingsDestination.allCases {
            #expect(
                SettingsDestination(area: destination.area)
                    == destination
            )
        }
        // And every area is claimed by exactly one destination.
        let owners = SettingsArea.allCases.map {
            SettingsDestination(area: $0)
        }
        #expect(Set(owners).count == owners.count)
        #expect(
            owners.count
                == SettingsDestination.allCases.count
        )
    }
}
