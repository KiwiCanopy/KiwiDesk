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
    /// The one door every quit path takes: the app's own windows,
    /// kept by its delegate.
    static func clearOwnWindows() -> Bool {
        clear(NSApp.windows, keeper: NSApp.delegate as? QuitSheetKeeper)
    }

    /// Answers whether the quit may proceed. While `keeper` keeps
    /// a sheet nothing closes and `keeper` is told; otherwise
    /// every sheet ends as Cancel.
    static func clear(
        _ windows: [NSWindow],
        keeper: QuitSheetKeeper?
    ) -> Bool {
        let hosts = windows.filter {
            $0.sheetParent == nil && $0.attachedSheet != nil
        }
        if let keeper, hosts.contains(where: keeper.keepsSheet) {
            keeper.quitRefused()
            return false
        }
        hosts.forEach(endSheets)
        return true
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
