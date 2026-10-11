import ApplicationServices
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
        element: AXUIElement?,
        channel: String
    ) {
        // The gate's own #2072 escape: a buttoned window it is
        // about to admit is no panel. An activation carries no
        // element and reads as one.
        let button =
            FloatDetection.needsTitlebarButton(
                layer: FloatDetection.windowLayer(of: id) ?? 0,
                isAccessory: isAccessory
            )
            && element.map { Self.readsTitlebarButton($0, id: id) } == true
        if FloatDetection.isBuiltInIgnoredPanel(
            bundleID: bundleID,
            id: id,
            isAccessory: isAccessory,
            titlebarButton: button
        ) {
            onLog(
                "\(channel): untracked w\(id.raw) "
                    + "(\(bundleID ?? "?")) "
                    + "flagged ignored panel"
            )
            onIgnoredPanelFocus(pid, bundleID)
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
