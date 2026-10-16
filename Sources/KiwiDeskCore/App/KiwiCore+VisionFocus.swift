import Foundation

/// A lens's hold on the keyboard (#2103 rulings 30, 35, 36): while
/// a lens keeps focus on its apps, KiwiDesk's focus and swap keys
/// skip other apps' windows; while a lens is on, the window
/// switcher lists its apps first. A click, the bars, hover focus
/// and a scroll gesture are deliberate picks and skip nothing.
extension KiwiCore {
    /// The apps the lens on holds, by `AppRef.listKey`; nil while
    /// no lens is on.
    var visionLensApps: Set<String>? {
        visionLook.lens.map { Set($0.apps) }
    }

    /// The apps the lens on keeps focus on; nil while no lens is on
    /// or its "Keep focus on these apps" is off.
    var lensFocusApps: Set<String>? {
        guard visionLook.lens?.keepFocus == true else { return nil }
        return visionLensApps
    }

    /// The windows the focus and swap keys skip now: every window
    /// whose app the lens on does not hold (rulings 30, 35). Nil
    /// while no lens keeps focus.
    func lensKeySkip() -> ((WindowID) -> Bool)? {
        guard let apps = lensFocusApps else { return nil }
        return { [state] id in
            guard let window = state.windows[id] else { return false }
            return !apps.contains(window.appRef.listKey)
        }
    }
}

extension ManagedWindow {
    /// The app this window belongs to, as an app list names it.
    var appRef: AppRef { AppRef(bundleID: appBundleID, name: appName) }
}
