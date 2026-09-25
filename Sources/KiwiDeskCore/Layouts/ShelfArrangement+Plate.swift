import CoreGraphics

extension ShelfArrangement {
    /// The one plate's span along an edge `length` long (#1517):
    /// none while every item draws its own box, the whole edge
    /// under Full, else the union of the runs' `asks` (an empty
    /// ask asks nothing) — one joined plate. The live shelf and
    /// the Settings preview both ask it.
    public static func plateSpan(
        asks: [ClosedRange<CGFloat>],
        length: CGFloat,
        shelf: KiwiShelf
    ) -> ClosedRange<CGFloat>? {
        guard shelf.drawsPlate else { return nil }
        if shelf.plateSpans { return 0...max(length, 0) }
        let real = asks.filter { $0.upperBound > $0.lowerBound }
        guard let first = real.first else { return nil }
        return real.dropFirst().reduce(first) {
            min(
                $0.lowerBound,
                $1.lowerBound
            )...max($0.upperBound, $1.upperBound)
        }
    }
}
