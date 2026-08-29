import CoreGraphics

/// What the float fit last ASKED of a window, and what the
/// window still reported afterwards (#1091).
///
/// The retile-time fit shrinks a float that no longer fits the
/// region its bars leave. Unlike the clamp beside it, that ask
/// can be REFUSED: a position is nearly always accepted, while
/// an app with a minimum size larger than the space between two
/// bars simply keeps its size. The sweep compares frames
/// exactly, so a refused fit was re-issued on every retile,
/// forever, to an app already known to refuse it.
///
/// This is #677's shape, one subsystem over: learn the refusal
/// from our own ask and stop re-issuing. It is deliberately NOT
/// an entry in `SizeBoundLearner` — state-and-layout.md rules
/// that only the layout loop records asks there, because a bound
/// keyed to a frame no layout re-issues would then be consumed
/// by passes that never asked for it, and a float never enters
/// `layoutInput` at all.
///
/// The evidence is a PAIR: the size asked for, and the size the
/// window was still reporting when we asked. A later sweep that
/// would issue the same ask against the same reported size is
/// re-asking a question already answered, and skips. Anything
/// that moves either half — the user resizing the window, the
/// app changing its own mind, a bar edit changing the region —
/// produces a different pair and asks again, so nothing has to
/// invalidate this explicitly.
struct FloatFitLedger {
    private var refused: [WindowID: (asked: CGSize, seen: CGSize)] =
        [:]

    /// Whether asking `window` for `asked` while it reports
    /// `seen` would repeat an ask this window already ignored.
    func repeatsRefusal(
        _ window: WindowID,
        asked: CGSize,
        seen: CGSize
    ) -> Bool {
        guard let entry = refused[window] else { return false }
        return entry.asked == asked && entry.seen == seen
    }

    /// Record an ask, so the next identical one can be skipped.
    /// Recorded at the ASK rather than on an observed refusal:
    /// the answer arrives asynchronously as an echo, and a
    /// window that complies simply stops being oversized and
    /// never consults this again.
    mutating func record(
        _ window: WindowID,
        asked: CGSize,
        seen: CGSize
    ) {
        refused[window] = (asked, seen)
    }

    /// Drop a window's entry — called for a float that needs no
    /// fit, which keeps the table to the windows actually
    /// fighting and means a window that later needs one is
    /// asked afresh.
    mutating func forget(_ window: WindowID) {
        refused[window] = nil
    }
}
