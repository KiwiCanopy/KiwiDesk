import CoreGraphics

/// The committed SkyLight transaction a ring panel's move rides
/// (#1956); os-private-apis.md says why it carries no order (#1962).
extension SkyLight {
    typealias TransactionCreateFn =
        @convention(c) (ConnectionID) -> Unmanaged<CFTypeRef>?
    typealias TransactionCommitFn =
        @convention(c) (CFTypeRef, Int32) -> CGError

    static let transactionCreateSymbol = symbol(
        "SLSTransactionCreate",
        as: TransactionCreateFn.self
    )
    static var transactionCreate: TransactionCreateFn? {
        transactionCreateSymbol.function
    }
    static let transactionCommitSymbol = symbol(
        "SLSTransactionCommit",
        as: TransactionCommitFn.self
    )
    static var transactionCommit: TransactionCommitFn? {
        transactionCommitSymbol.function
    }
}
