import AppKit

/// The picker panel's content: the picker's hosting view, and above
/// it the drop (#3700).
@MainActor
final class LookPickerContent: NSView {
    let picker: NSView
    let drop: NSView

    init(picker: NSView, drop: NSView) {
        self.picker = picker
        self.drop = drop
        super.init(frame: .zero)
        for view in [picker, drop] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
