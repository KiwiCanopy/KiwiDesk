import AppKit

/// A key-opened list (#2974): a row starts lifted, since a key has no
/// pointer, and each button speaks, since no menu twins this list as
/// one does a click's.
extension BarPeekBody {
    /// Lifts the button at `index`, or the first window's, a tall
    /// list's "more" line standing ahead of it on a bottom bar; an
    /// empty Pocket's first row where it lists none.
    func liftRow(_ index: Int?) {
        guard !targets.isEmpty else { return }
        let first = targets.firstIndex {
            if case .window = $0.action { return true }
            return false
        }
        setHovered(index.map { min($0, targets.count - 1) } ?? first ?? 0)
    }

    /// The pointer on the button at `index`, or on none. A key-opened
    /// list keeps its lifted row: Return must never lose it to a nudge.
    func pointerHovers(_ index: Int?) {
        guard index != nil || !keyed else { return }
        setHovered(index)
    }

    /// A row's name: its title, then its Pocket key in words.
    static func spokenRow(_ row: BarPeekContent.Row) -> String {
        row.spokenChord.map { "\(row.title), \($0)" } ?? row.title
    }

    /// One button per target, over its frame, its labels already quiet
    /// (`BarPeekBody.style`); the body's `hitTest` keeps every press
    /// its own.
    func addRowButtons() {
        rowButtons = targets.map { target in
            let button = BarPeekRowButton(frame: target.frame)
            button.setAccessibilityLabel(
                target.spoken
                    ?? (target.inks.first as? NSTextField)?.stringValue
            )
            let action = target.action
            button.onPress = { [weak self] in self?.act(action) }
            addSubview(button)
            return button
        }
    }

    /// Moves VoiceOver's cursor onto the lifted row, as the arrows
    /// move the highlight.
    func speakLiftedRow() {
        guard keyed, let hovered, hovered < rowButtons.count else {
            return
        }
        moveVoiceOver(rowButtons[hovered])
    }
}

/// A row of a key-opened list, to VoiceOver alone (#2974).
final class BarPeekRowButton: NSView {
    var onPress: @MainActor () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
