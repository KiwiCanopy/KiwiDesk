import Foundation

/// The untracked-focus classification the two report channels
/// share (#21/#244): a focus report for a window tracking
/// ignored either arms the ignored-panel distrust or is
/// dropped on the floor — and WHICH of the two happened is
/// exactly what the #951 capture must show, so both outcomes
/// narrate through `onLog`.
extension EventLoop {
    func classifyUntrackedFocus(
        id: WindowID,
        pid: pid_t,
        bundleID: String?,
        isAccessory: Bool,
        channel: String
    ) {
        if FloatDetection.isBuiltInIgnoredPanel(
            bundleID: bundleID,
            id: id,
            isAccessory: isAccessory
        ) {
            onLog(
                "\(channel): untracked w\(id.raw) "
                    + "(\(bundleID ?? "?")) "
                    + "flagged ignored panel"
            )
            onIgnoredPanelFocus(pid)
        } else {
            // In NEITHER class: no #244 distrust arms, so the
            // app's dismissal re-report will be honored.
            onLog(
                "\(channel): untracked w\(id.raw) "
                    + "(\(bundleID ?? "?")) "
                    + "dropped, no panel flag"
            )
        }
    }
}
