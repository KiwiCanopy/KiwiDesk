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
            floors: [],
            minimum: 0
        )
        #expect(widths == [200, 100, 100])
    }

    @Test("Only the first n weights apply")
    func firstNApply() {
        let widths = GridTracks.lengths(
            count: 2,
            weights: [3, 1, 5, 5],
            span: 400,
            floors: [],
            minimum: 0
        )
        #expect(widths == [300, 100])
    }

    @Test("A track under its floor is lifted from the others")
    func floorLifts() {
        let widths = GridTracks.lengths(
            count: 3,
            weights: [8, 1, 1],
            span: 1000,
            floors: [0, 200, 0],
            minimum: 0
        )
        #expect(widths[1] == 200)
        // The rest share what is left by weight, 8 : 1.
        #expect(abs(widths[0] - 711.11) < 0.01)
        #expect(abs(widths[2] - 88.89) < 0.01)
    }

    @Test("Floors that cannot fit fall back to the configured one")
    func unfitFloorsKeepTheMinimum() {
        let widths = GridTracks.lengths(
            count: 2,
            weights: [0.01, 1],
            span: 400,
            floors: [300, 300],
            minimum: 100
        )
        #expect(widths == [100, 300])
    }

    @Test("Past the configured floor the weights alone decide")
    func unfitMinimumIsProportional() {
        let widths = GridTracks.lengths(
            count: 2,
            weights: [1, 3],
            span: 400,
            floors: [],
            minimum: 300
        )
        #expect(widths == [100, 300])
    }

    /// The render with no floors, for the edge-move cases.
    private func plain(_ count: Int) -> ([Double]) -> [CGFloat] {
        {
            GridTracks.lengths(
                count: count,
                weights: $0,
                span: 900,
                floors: [],
                minimum: 0
            )
        }
    }

    @Test("A moved edge keeps its pair's weight sum")
    func pairSumHolds() throws {
        let step = try #require(
            GridTracks.moveEdge(
                weights: [1, 1, 1],
                grown: 0,
                neighbor: 1,
                floors: [100, 100, 100],
                delta: 60,
                draw: plain(3)
            )
        )
        #expect(abs(step.weights[0] - 1.2) < 0.000_01)
        #expect(abs(step.weights[1] - 0.8) < 0.000_01)
        try #require(step.weights.count == 3)
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
                floors: [250, 100],
                delta: 400,
                draw: plain(2)
            )
        )
        let drawn = plain(2)(step.weights)
        #expect(abs(drawn[0] - 250) < 0.01)
        #expect(step.clamped)
    }

    @Test("A pair that cannot hold both floors refuses")
    func unfitPairRefuses() {
        #expect(
            GridTracks.moveEdge(
                weights: [],
                grown: 0,
                neighbor: 1,
                floors: [500, 500],
                delta: 10,
                draw: plain(2)
            ) == nil
        )
    }

    /// The architect's case: column 0 lifted to a 700-pt floor in
    /// an 1800-pt span draws 700/550/550; growing it by 50 must
    /// draw 750/500/550, never move column 2.
    @Test("A press on a lifted column lands what the render draws")
    func liftedColumnLandsTheDelta() throws {
        let draw: ([Double]) -> [CGFloat] = {
            GridTracks.lengths(
                count: 3,
                weights: $0,
                span: 1800,
                floors: [700, 0, 0],
                minimum: 0
            )
        }
        #expect(draw([]) == [700, 550, 550])
        let step = try #require(
            GridTracks.moveEdge(
                weights: [],
                grown: 0,
                neighbor: 1,
                floors: [700, 0, 0],
                delta: 50,
                draw: draw
            )
        )
        let after = draw(step.weights)
        #expect(abs(after[0] - 750) < 0.5)
        #expect(abs(after[1] - 500) < 0.5)
        #expect(abs(after[2] - 550) < 0.5)
    }

    /// Floors 600 and 800 overfill a 1300-pt span, so the render
    /// keeps the configured floor alone and draws 433 each; a
    /// shrink of column 1 must not jump it up to its 600 floor.
    @Test("A shrink never moves the edge the other way")
    func shrinkNeverGrows() throws {
        let draw: ([Double]) -> [CGFloat] = {
            GridTracks.lengths(
                count: 3,
                weights: $0,
                span: 1300,
                floors: [600, 0, 800],
                minimum: 100
            )
        }
        let before = draw([])[0]
        let step = try #require(
            GridTracks.moveEdge(
                weights: [],
                grown: 0,
                neighbor: 1,
                floors: [600, 0, 800],
                delta: -50,
                draw: draw
            )
        )
        #expect(draw(step.weights)[0] <= before + 0.01)
        #expect(step.clamped)
    }

    @Test("A write never shortens the stored list")
    func neverTruncates() throws {
        let step = try #require(
            GridTracks.moveEdge(
                weights: [1, 1, 3, 2],
                grown: 0,
                neighbor: 1,
                floors: [0, 0],
                delta: 20,
                draw: plain(2)
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
