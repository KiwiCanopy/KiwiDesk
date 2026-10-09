/// A private C function and the name it was looked up by (#1889):
/// the name is spelled once, at the lookup, so a `self_test` row
/// reads both from here and cannot name one symbol while checking
/// another.
struct PrivateSymbol<T> {
    let name: String
    let function: T?

    /// What a probe may read: never the callable function.
    var resolution: SymbolResolution {
        SymbolResolution(name: name, isResolved: function != nil)
    }
}

extension PrivateSymbol: Sendable where T: Sendable {}

/// A symbol's name and whether it resolved — nothing callable.
struct SymbolResolution: Sendable, Equatable {
    let name: String
    let isResolved: Bool
}
