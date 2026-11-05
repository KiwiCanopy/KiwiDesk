import CoreGraphics

/// A float whose size macOS says cannot be set (#2994). A short answer
/// proves nothing, since a cell grid and a late app give one too, so
/// only that statement ends a refused ask. It is heard per write and
/// kept nowhere (`docs/design-decisions.md` ▸ A refused size moves
/// nothing).
extension KiwiCore {
    func wireFixedSizeAnswer() {
        tiler.applier.fixedSizeDoor.onReport = { [weak self] in
            self?.handleFixedSize($0)
        }
    }

    /// Ends the write's run and draws the app's limit, once for the
    /// writes already out. The report lands after its hotkey fire, so
    /// `reportingPress` stands in for that fire at the funnel's sound.
    func handleFixedSize(_ report: FixedSizeReport) {
        let applier = tiler.applier
        let id = report.window
        guard report.serial > applier.fixedSizeDoor.cuedThrough,
            resizeRoutesAsFloat(id)
        else { return }
        applier.fixedSizeDoor.cuedThrough = applier.fixedSizeDoor.serial
        tiler.endSizeLedRun(of: id, anchor: report.anchor)
        endFloatAspectAsk(of: id)
        updateBorders()
        let width = report.asked.width - report.anchor.width
        let height = report.asked.height - report.anchor.height
        let horizontal = abs(width) >= abs(height)
        applier.fixedSizeDoor.reportingPress = report.pressed
        defer { applier.fixedSizeDoor.reportingPress = false }
        refuseFixedSize(
            id,
            axis: horizontal ? "x" : "y",
            shrinks: (horizontal ? width : height) < 0
        )
    }
}
