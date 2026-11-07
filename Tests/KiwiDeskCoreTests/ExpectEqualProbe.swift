import Testing

/// Measurement probe only: `#expect(a == b)` behind one generic call.
func expectEqual<T: Equatable>(
    _ a: T,
    _ b: T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(a == b, sourceLocation: sourceLocation)
}
