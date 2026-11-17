import Foundation

/// The pattern `TitlePatternPopover` holds before Add (#3340): a
/// picked open title or a typed one, never stored until committed,
/// so the popover's preview checks every pattern first.
struct TitlePatternDraft: Equatable {
    /// The field's text.
    var text = ""
    /// Whether the field is shown.
    private(set) var isOpen = false
    /// Counts `start` calls, so the field re-selects on each pick
    /// while it stays mounted.
    private(set) var picks = 0

    /// Opens the field on `title`, replacing any text being typed;
    /// an empty title opens it empty.
    mutating func start(with title: String = "") {
        text = title
        isOpen = true
        picks &+= 1
    }

    /// Closes the field and drops its text.
    mutating func cancel() {
        text = ""
        isOpen = false
    }

    /// The trimmed pattern to add, closing the field — nil, with
    /// the field left open, while it holds nothing to add.
    mutating func commit() -> String? {
        let pattern = text.trimmed
        guard !pattern.isEmpty else { return nil }
        cancel()
        return pattern
    }
}
