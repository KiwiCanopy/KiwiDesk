import Foundation
import os

/// Drains a child's stdout and stderr via `readabilityHandler`
/// and reports both, off the main thread, once both streams hit
/// EOF. No thread is ever blocked waiting for a pipe; GCD calls
/// the handler as data arrives. Split out of `ExecLauncher` for
/// file size.
///
/// Each stream is capped at `streamCap` bytes: data beyond the
/// cap is still read (keeping the pipe drained so the child can
/// keep writing without blocking) but discarded after the
/// truncation marker is appended.
final class OutputCapture: Sendable {
    /// Maximum bytes captured per stream (~1 MB).
    static let streamCap = 1_048_576
    /// Appended once when a stream's cap is reached.
    static let truncMark = Data(
        "\n[output truncated at 1 MB]\n".utf8
    )

    private let out: Pipe
    private let err: Pipe
    private let group = DispatchGroup()
    private let outBuf = OSAllocatedUnfairLock(
        initialState: (data: Data(), capped: false)
    )
    private let errBuf = OSAllocatedUnfairLock(
        initialState: (data: Data(), capped: false)
    )

    init(_ out: Pipe, _ err: Pipe) {
        self.out = out
        self.err = err
        // Enter for both streams up front: the termination
        // handler can fire before drain() runs on the main
        // actor, and an empty group would notify immediately
        // with empty output.
        group.enter()
        group.enter()
    }

    /// Starts both reads; must be called exactly once.
    func drain() {
        attach(out.fileHandleForReading, to: outBuf)
        attach(err.fileHandleForReading, to: errBuf)
    }

    private func attach(
        _ handle: FileHandle,
        to buf: OSAllocatedUnfairLock<
            (
                data: Data, capped: Bool
            )
        >
    ) {
        handle.readabilityHandler = { [group, buf] fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                // EOF: all write ends of the pipe are closed.
                fh.readabilityHandler = nil
                group.leave()
                return
            }
            buf.withLock { state in
                guard !state.capped else { return }
                let cap = OutputCapture.streamCap
                let space = cap - state.data.count
                if chunk.count <= space {
                    state.data.append(chunk)
                } else {
                    if space > 0 {
                        state.data.append(
                            chunk.prefix(space)
                        )
                    }
                    state.data.append(
                        OutputCapture.truncMark
                    )
                    state.capped = true
                }
            }
        }
    }

    /// A best-effort read of what has been captured so far,
    /// without waiting for EOF. Used by the timeout force-reap
    /// when a stuck pipe means `onComplete` may never fire.
    func snapshot() -> (String, String) {
        let outData = outBuf.withLock { $0.data }
        let errData = errBuf.withLock { $0.data }
        return (
            String(decoding: outData, as: UTF8.self),
            String(decoding: errData, as: UTF8.self)
        )
    }

    /// Calls `handler` (on a background queue) once both
    /// streams have hit EOF.
    func onComplete(
        _ handler:
            @escaping @Sendable (
                String, String
            ) -> Void
    ) {
        group.notify(
            queue: .global(qos: .utility)
        ) { [outBuf, errBuf] in
            let outData = outBuf.withLock { $0.data }
            let errData = errBuf.withLock { $0.data }
            handler(
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self)
            )
        }
    }
}
