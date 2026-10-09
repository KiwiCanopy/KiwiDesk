import AppKit

/// Answers which open sheet a quit must not close (#2049): one
/// guarding unsaved Settings work. Every other sheet is a
/// confirmation, closed as Cancel.
@MainActor
protocol QuitSheetKeeper: AnyObject {
    /// Whether `window`'s attached sheet guards unsaved work.
    func keepsSheet(on window: NSWindow) -> Bool
    /// A quit stood down for a kept sheet; show it.
    func quitRefused()
}

/// Clears own windows' sheets ahead of a quit, restart or logout
/// (#2049). AppKit ends an `NSAlert` sheet itself but aborts the
/// termination for any other sheet — a SwiftUI
/// `.confirmationDialog` or `.sheet` — so the quit never arrives.
@MainActor
enum QuitSheets {
    /// Ends every confirmation sheet as Cancel and answers whether
    /// the quit may proceed: false while `keeper` keeps a sheet,
    /// after telling it so.
    static func clear(
        _ windows: [NSWindow],
        keeper: QuitSheetKeeper?
    ) -> Bool {
        var kept = false
        for window in windows
        where window.sheetParent == nil && window.attachedSheet != nil {
            if keeper?.keepsSheet(on: window) == true {
                kept = true
            } else {
                endSheets(of: window)
            }
        }
        if kept { keeper?.quitRefused() }
        return !kept
    }

    /// Innermost first; a sheet that will not leave stops the loop.
    private static func endSheets(of window: NSWindow) {
        while let sheet = window.attachedSheet {
            endSheets(of: sheet)
            window.endSheet(sheet, returnCode: .cancel)
            if window.attachedSheet === sheet { return }
        }
    }
}
