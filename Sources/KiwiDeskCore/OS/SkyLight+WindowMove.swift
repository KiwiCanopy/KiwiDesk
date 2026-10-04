import CoreGraphics

/// Moves one of OUR windows in a committed transaction, without
/// AppKit's fence (#1956). The commit waits for no reply, and
/// AppKit's cached frame follows WindowServer's moved event
/// (device-checked macOS 27.0.1, 2026-10-05).
extension SkyLight {
    typealias TransactionMoveFn =
        @convention(c) (CFTypeRef, CGWindowID, CGPoint) -> CGError

    static let transactionMove: TransactionMoveFn? = symbol(
        "SLSTransactionMoveWindowWithGroup",
        as: TransactionMoveFn.self
    )

    /// Moves `window`'s top-left corner to `origin`, in global
    /// display coordinates with a top-left origin; false when a
    /// symbol is missing, and the caller moves through AppKit.
    /// The mutators return no usable status: a refused window id
    /// answers like a moved one (device 2026-10-05).
    static func moveWindow(
        _ window: CGWindowID,
        to origin: CGPoint
    ) -> Bool {
        guard let mainConnection, let transactionCreate,
            let transactionMove, let transactionCommit,
            let transaction = transactionCreate(mainConnection())?
                .takeRetainedValue()
        else { return false }
        _ = transactionMove(transaction, window, origin)
        _ = transactionCommit(transaction, 0)
        return true
    }
}
