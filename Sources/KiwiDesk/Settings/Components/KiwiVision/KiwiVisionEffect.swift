import KiwiDeskCore

/// What KiwiVision's picture shows at the running values; the
/// caption and the spoken label read the same facts (#2103). The
/// caption is two whole sentences, each its own key — what the
/// haze covers, then what focusing does (ruling 20) — joined by a
/// frame so a locale chooses the separator.
@MainActor
struct KiwiVisionEffect: Equatable {
    var dims: Bool
    var blurs: Bool
    /// Whether the wallpaper stays clear (#2103 ruling 17).
    var windowsOnly = false
    /// Whether the focused app's other windows stay clear.
    var clearApp = false

    var caption: String {
        guard let haze else {
            return L(
                "kiwivision.preview.caption.none",
                "At these settings KiwiVision changes nothing on screen."
            )
        }
        return L(
            "kiwivision.preview.caption.frame",
            "%1$@ %2$@",
            haze,
            follow
        )
    }

    /// One VoiceOver element, the number last (localization.md).
    func spoken(dimPercent: Double) -> String {
        guard haze != nil else {
            return L(
                "kiwivision.preview.ax.none",
                "KiwiVision preview: nothing changes at these settings."
            )
        }
        let spoken = L(
            "kiwivision.preview.ax.frame",
            "KiwiVision preview: %1$@",
            caption
        )
        guard dims else { return spoken }
        return L(
            "kiwivision.preview.ax.dim_value",
            "%1$@ Dim: %2$@",
            spoken,
            SettingsValueReadout.percent(dimPercent / 100)
        )
    }

    /// What focusing another window does.
    private var follow: String {
        guard clearApp else {
            return L(
                "kiwivision.preview.caption.follow.window",
                "Focus another window and it becomes the clear one."
            )
        }
        return L(
            "kiwivision.preview.caption.follow.app",
            "Focus another app's window and its windows become the "
                + "clear ones."
        )
    }

    /// What the haze covers, nil where it covers nothing.
    private var haze: String? {
        switch (windowsOnly, clearApp) {
        case (false, false): return screenHaze
        case (true, false): return windowsHaze
        case (false, true): return appScreenHaze
        case (true, true): return appWindowsHaze
        }
    }

    private var appScreenHaze: String? {
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.caption.haze.app.dim_blur",
                "Everything but the focused app's windows is dimmed "
                    + "and blurred."
            )
        case (true, false):
            return L(
                "kiwivision.preview.caption.haze.app.dim",
                "Everything but the focused app's windows is dimmed."
            )
        case (false, true):
            return L(
                "kiwivision.preview.caption.haze.app.blur",
                "Everything but the focused app's windows is blurred."
            )
        case (false, false):
            return nil
        }
    }

    private var appWindowsHaze: String? {
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.caption.haze.app.windows.dim_blur",
                "Other apps' windows are dimmed and blurred; the "
                    + "wallpaper stays clear."
            )
        case (true, false):
            return L(
                "kiwivision.preview.caption.haze.app.windows.dim",
                "Other apps' windows are dimmed; the wallpaper stays "
                    + "clear."
            )
        case (false, true):
            return L(
                "kiwivision.preview.caption.haze.app.windows.blur",
                "Other apps' windows are blurred; the wallpaper stays "
                    + "clear."
            )
        case (false, false):
            return nil
        }
    }

    private var screenHaze: String? {
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.caption.haze.dim_blur",
                "Everything but the focused window is dimmed and blurred."
            )
        case (true, false):
            return L(
                "kiwivision.preview.caption.haze.dim",
                "Everything but the focused window is dimmed."
            )
        case (false, true):
            return L(
                "kiwivision.preview.caption.haze.blur",
                "Everything but the focused window is blurred."
            )
        case (false, false):
            return nil
        }
    }

    private var windowsHaze: String? {
        switch (dims, blurs) {
        case (true, true):
            return L(
                "kiwivision.preview.caption.haze.windows.dim_blur",
                "The windows behind the focused one are dimmed and "
                    + "blurred; the wallpaper stays clear."
            )
        case (true, false):
            return L(
                "kiwivision.preview.caption.haze.windows.dim",
                "The windows behind the focused one are dimmed; the "
                    + "wallpaper stays clear."
            )
        case (false, true):
            return L(
                "kiwivision.preview.caption.haze.windows.blur",
                "The windows behind the focused one are blurred; the "
                    + "wallpaper stays clear."
            )
        case (false, false):
            return nil
        }
    }
}
