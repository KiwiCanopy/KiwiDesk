import Testing

@testable import KiwiDesk

/// The Monitors area's census gates (#678 Phase 3, turn 13b).
///
/// Every gate here SURFACES rather than greys, and one runtime
/// condition drives two opposite outcomes — it surfaces the
/// not-connected banner and withholds the cards the banner stands
/// in for. That pairing is the thing worth guarding: a resolver
/// that answered one side and not the other would leave the page
/// with both on screen, or neither.
@Suite("Monitors gates")
struct MonitorsGateTests {
    private func gates(
        editing: Bool = false,
        editable: Bool = true,
        orphans: Bool = false
    ) -> MonitorsGates {
        MonitorsGates(
            editingStoredProfile: editing,
            placementEditable: editable,
            hasOrphanedPins: orphans
        )
    }

    @Test("a live edit target draws the picture")
    func liveShowsThePicture() {
        let live = gates()
        #expect(
            live.inertReason(for: .monitors(.spacePins)) == nil
        )
        #expect(
            live.inertReason(for: .monitors(.mainSpaces)) == nil
        )
        #expect(
            live.inertReason(
                for: .monitors(.placementUnavailable)
            ) == .pictureIsDrawable
        )
    }

    /// The banner and the cards are exact complements. Asserted
    /// as a pair rather than one at a time, because the failure
    /// that matters is them disagreeing.
    @Test("an away profile swaps the picture for the banner")
    func awayShowsTheBanner() {
        let away = gates(editing: true, editable: false)
        #expect(
            away.inertReason(for: .monitors(.spacePins))
                == .noLiveGeometry
        )
        #expect(
            away.inertReason(for: .monitors(.mainSpaces))
                == .noLiveGeometry
        )
        #expect(
            away.inertReason(
                for: .monitors(.placementUnavailable)
            ) == nil
        )
    }

    /// Both arms of the condition, since the census tag names a
    /// CONJUNCTION: editing a stored profile whose monitors are
    /// away. Either half alone leaves the picture drawable, and a
    /// resolver that dropped one would blank the page for every
    /// stored-profile edit.
    @Test("both arms are needed to lose the picture")
    func conjunctionNeedsBothArms() {
        #expect(!gates(editing: true, editable: true).monitorsDisconnected)
        #expect(
            !gates(editing: false, editable: false)
                .monitorsDisconnected
        )
        #expect(
            gates(editing: true, editable: false)
                .monitorsDisconnected
        )
    }

    @Test("the orphan card exists only while a pin is orphaned")
    func orphanCardSurfaces() {
        #expect(
            gates(orphans: false)
                .inertReason(for: .monitors(.orphanPinClear))
                == .noOrphanedPins
        )
        #expect(
            gates(orphans: true)
                .inertReason(for: .monitors(.orphanPinClear))
                == nil
        )
    }

    /// An ungated key is never inert, whatever the state — the
    /// resolver answers gates, not rows.
    @Test("an ungated row is never withheld")
    func ungatedRowsStayPut() {
        #expect(
            gates(editing: true, editable: false)
                .inertReason(for: .monitors(.fingerprints)) == nil
        )
    }

    /// Every gate the census declares in this area is answered by
    /// the resolver or deliberately assigned elsewhere. Data, so
    /// a new gate landing in neither set reds here rather than
    /// hitting the fail-open default at run time.
    @Test("every gated row is resolved")
    func everyGatedRowIsResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .monitors
                    && $0.placement.gate != nil
            }
        )
        #expect(!gated.isEmpty)
        #expect(
            gated
                == MonitorsGates.resolved
                .union(MonitorsGates.resolvedElsewhere)
        )
        #expect(
            MonitorsGates.resolved
                .intersection(MonitorsGates.resolvedElsewhere)
                .isEmpty
        )
    }

    /// No container in this area carries a gate — the resolver
    /// has no `containerReason` arm, so a container gate here
    /// would withhold a whole card with nothing to resolve it,
    /// and the row-gate net above cannot see one.
    @Test("the area carries no container gate")
    func noContainerGate() {
        let containers = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .monitors }
                .compactMap { $0.placement.container }
        )
        #expect(!containers.isEmpty)
        for container in containers {
            #expect(
                container.gate == nil,
                Comment(
                    rawValue:
                        "\(container) declares a container gate "
                        + "that MonitorsGates cannot answer"
                )
            )
        }
    }
}
