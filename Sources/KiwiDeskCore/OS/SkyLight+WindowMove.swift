import CoreGraphics

/// Moves one of OUR windows in a committed transaction (#1956):
/// AppKit's `setFrame` ties a move to the next Core Animation
/// commit with a fence, and a WindowServer read on the main actor
/// waits for that fence while another app's window transaction
/// holds WindowServer up. The commit waits for no reply; AppKit
/// learns the new frame from WindowServer's moved event.
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
