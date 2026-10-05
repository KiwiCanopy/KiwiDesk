import CoreGraphics

/// The committed SkyLight transaction a ring panel's move rides
/// (#1956). It carries no ORDER: WindowServer applies none to an
/// AppKit panel, so a ring re-stacks through AppKit (#1962).
extension SkyLight {
    typealias TransactionCreateFn =
        @convention(c) (ConnectionID) -> Unmanaged<CFTypeRef>?
    typealias TransactionCommitFn =
        @convention(c) (CFTypeRef, Int32) -> CGError

    static let transactionCreate: TransactionCreateFn? = symbol(
        "SLSTransactionCreate",
        as: TransactionCreateFn.self
    )
    static let transactionCommit: TransactionCommitFn? = symbol(
        "SLSTransactionCommit",
        as: TransactionCommitFn.self
    )
}
