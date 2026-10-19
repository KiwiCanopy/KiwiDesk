import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `GridTracks`, the pure track sizing behind grid resize (#763):
/// the owner's ruling read as arithmetic — first n weights apply,
/// a track past the list draws at 1, the list never shrinks, and
/// a moved edge keeps its pair's sum.
@Suite("Grid track weights (#763)")
struct GridTracksTests {
    @Test("A track past the stored list draws an equal share")
    func pastTheListIsEqual() {
        let widths = GridTracks.lengths(
            count: 3,
            weights: [2],
            span: 400,
            floors: []
        )
        #expect(widths == [200, 100, 100])
    }

    @Test("Only the first n weights apply")
    func firstNApply() {
        let widths = GridTracks.lengths(
            count: 2,
            weights: [3, 1, 5, 5],
            span: 400,
            floors: []
        )
        #expect(widths == [300, 100])
    }

    @Test("A track under its floor is lifted from the others")
    func floorLifts() {
        let widths = GridTracks.lengths(
            count: 3,
            weights: [8, 1, 1],
            span: 1000,
            floors: [0, 200, 0]
        )
        #expect(widths[1] == 200)
        // The rest share what is left by weight, 8 : 1.
        #expect(abs(widths[0] - 711.11) < 0.01)
        #expect(abs(widths[2] - 88.89) < 0.01)
    }

    @Test("Floors that cannot fit leave the weights to decide")
    func unfitFloorsFallBack() {
        let widths = GridTracks.lengths(
            count: 2,
            weights: [1, 1],
            span: 400,
            floors: [300, 300]
        )
        #expect(widths == [200, 200])
    }

    @Test("A moved edge keeps its pair's weight sum")
    func pairSumHolds() throws {
        let step = try #require(
            GridTracks.moveEdge(
                weights: [1, 1, 1],
                grown: 0,
                neighbor: 1,
                lengths: (300, 300),
                floors: (100, 100),
                delta: 60
            )
        )
        #expect(abs(step.weights[0] - 1.2) < 0.000_001)
        #expect(abs(step.weights[1] - 0.8) < 0.000_001)
        #expect(step.weights[2] == 1)
        #expect(!step.clamped)
    }

    @Test("An edge stops at the neighbour's floor and says so")
    func clampsAtNeighborFloor() throws {
        let step = try #require(
            GridTracks.moveEdge(
                weights: [],
                grown: 1,
                neighbor: 0,
                lengths: (300, 300),
                floors: (100, 250),
                delta: 200
            )
        )
        // The neighbour keeps 250 of the pair's 600.
        #expect(abs(step.weights[0] - 2 * 250 / 600) < 0.000_001)
        #expect(step.clamped)
    }

    @Test("A pair that cannot hold both floors refuses")
    func unfitPairRefuses() {
        #expect(
            GridTracks.moveEdge(
                weights: [],
                grown: 0,
                neighbor: 1,
                lengths: (150, 150),
                floors: (200, 200),
                delta: 10
            ) == nil
        )
    }

    @Test("A write never shortens the stored list")
    func neverTruncates() throws {
        let step = try #require(
            GridTracks.moveEdge(
                weights: [1, 1, 3, 2],
                grown: 0,
                neighbor: 1,
                lengths: (200, 200),
                floors: (0, 0),
                delta: 20
            )
        )
        #expect(step.weights.count == 4)
        #expect(Array(step.weights[2...]) == [3, 2])
    }

    @Test("Trailing equal shares leave the stored list")
    func trimmedDropsTrailingOnes() {
        #expect(GridTracks.trimmed([2, 1, 1]) == [2])
        #expect(GridTracks.trimmed([1, 1]) == [])
        #expect(GridTracks.trimmed([1, 2]) == [1, 2])
    }

    @Test("A filling last cell spans the rest of its row")
    func fillLastSpans() {
        let cell = GridTracks.cell(
            4,
            count: 5,
            columns: 3,
            rows: 2,
            rowMajor: true,
            fillLast: true
        )
        #expect(cell.columns == .init(first: 1, last: 2))
        #expect(cell.rows == .init(first: 1, last: 1))
    }
}
