import AppKit

/// Closes own windows' sheets ahead of a quit, restart or logout,
/// each as Cancel (#2049). AppKit ends an `NSAlert` sheet itself
/// but aborts the termination for any other sheet — a SwiftUI
/// `.confirmationDialog` or `.sheet` — so the quit never arrives.
@MainActor
enum QuitSheets {
    /// The one door every quit path takes: the app's own windows.
    static func clearOwnWindows() {
        clear(NSApp.windows)
    }

    /// Ends every sheet of `windows` as Cancel, innermost first.
    static func clear(_ windows: [NSWindow]) {
        for window in windows
        where window.sheetParent == nil && window.attachedSheet != nil {
            endSheets(of: window)
        }
    }

    /// A sheet that will not leave stops the loop.
    private static func endSheets(of window: NSWindow) {
        while let sheet = window.attachedSheet {
            endSheets(of: sheet)
            window.endSheet(sheet, returnCode: .cancel)
            if window.attachedSheet === sheet { return }
        }
    }
}
