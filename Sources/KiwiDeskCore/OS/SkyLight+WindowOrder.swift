import CoreGraphics

/// Re-stacks one of OUR windows against another app's window in a
/// committed transaction (#1925): AppKit's `order(_:relativeTo:)`
/// looks the other window's rights up synchronously first, and the
/// commit waits for no reply. Stacking device-checked on macOS 27,
/// Mission Control and popovers included (2026-10-03).
extension SkyLight {
    typealias TransactionCreateFn =
        @convention(c) (ConnectionID) -> Unmanaged<CFTypeRef>?
    typealias TransactionOrderFn =
        @convention(c) (
            CFTypeRef, CGWindowID, Int32, CGWindowID
        ) -> CGError
    typealias TransactionCommitFn =
        @convention(c) (CFTypeRef, Int32) -> CGError

    static let transactionCreate: TransactionCreateFn? = symbol(
        "SLSTransactionCreate",
        as: TransactionCreateFn.self
    )
    static let transactionOrder: TransactionOrderFn? = symbol(
        "SLSTransactionOrderWindow",
        as: TransactionOrderFn.self
    )
    static let transactionCommit: TransactionCommitFn? = symbol(
        "SLSTransactionCommit",
        as: TransactionCommitFn.self
    )

    /// Orders `window` directly above or below `target`; false when
    /// a symbol is missing, and the caller orders through AppKit.
    /// Only the transaction's creation gates: the mutators return
    /// no usable status (the pre-#1923 SkyLight ring's finding).
    static func orderWindow(
        _ window: CGWindowID,
        above: Bool,
        relativeTo target: CGWindowID
    ) -> Bool {
        guard let mainConnection, let transactionCreate,
            let transactionOrder, let transactionCommit,
            let transaction = transactionCreate(mainConnection())?
                .takeRetainedValue()
        else { return false }
        _ = transactionOrder(transaction, window, above ? 1 : -1, target)
        _ = transactionCommit(transaction, 0)
        return true
    }
}
