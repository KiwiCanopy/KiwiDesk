import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// A saved look's picture (#3478 ▸ menu ruling): Choose Wallpaper…,
/// Use Current Wallpaper and Remove Wallpaper, and a file dropped on
/// a tile. Every write goes through Core's one door
/// (`KiwiCore+LookWallpaperAttach`); this file narrates.
extension LooksShelf {
    /// The open panel for one picture on every screen.
    func chooseWallpaper(for look: ShelfLook) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = WallpaperLibrary.pictureTypes.map(\.type)
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("looks.wallpaper.choose_button", "Choose")
        panel.message = chooseMessage(for: look)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachWallpaper(at: url, to: look)
    }

    /// Copies the picture at `url` onto `look`, asking first when it
    /// is large; a drop on a tile takes this door too. The file is
    /// read off the main actor, since it may be tens of megabytes.
    func attachWallpaper(at url: URL, to look: ShelfLook) {
        Task { @MainActor in
            let read = Task.detached { try? Data(contentsOf: url) }
            guard let data = await read.value else {
                noteWallpaper(unreadableWallpaper, on: look.name)
                return
            }
            attachWallpaper(data, to: look)
        }
    }

    private func attachWallpaper(_ read: Data, to look: ShelfLook) {
        var data = read
        if data.count > WallpaperLibrary.largeBytes {
            switch askLargeWallpaper(data) {
            case .copy: break
            case .shrink:
                guard let shrunk = shrink(data) else {
                    noteWallpaper(unreadableWallpaper, on: look.name)
                    return
                }
                data = shrunk
            case .cancel: return
            }
        }
        do {
            try core.chooseLookWallpaper(data, for: look.name)
            noteWallpaper(nil, on: look.name)
        } catch WallpaperLibrary.Refusal.notAPicture {
            noteWallpaper(
                L(
                    "looks.wallpaper.not_picture",
                    "That file isn't a picture KiwiDesk can use."
                ),
                on: look.name
            )
        } catch {
            noteWallpaper(unreadableWallpaper, on: look.name)
        }
        reload()
    }

    /// Stores what each screen shows now.
    func useCurrentWallpaper(for look: ShelfLook) {
        let name = look.name
        Task { @MainActor in
            let outcomes = await core.useCurrentWallpaper(for: name)
            noteWallpaper(Self.narrate(outcomes, look: name), on: name)
            reload()
        }
    }

    func removeWallpaper(from look: ShelfLook) {
        do {
            try core.setLookWallpaper(nil, of: look.name)
            noteWallpaper(nil, on: look.name)
        } catch {
            noteWallpaper(
                L(
                    "looks.wallpaper.remove_failed",
                    "KiwiDesk couldn't remove the wallpaper from this look."
                ),
                on: look.name
            )
        }
        reload()
    }

    /// Why a wallpaper action on `look` stored nothing, shown off
    /// that look's tile and spoken (#3699); nil clears it.
    func noteWallpaper(_ text: String?, on look: String) {
        guard let text else {
            if wallpaperNotice?.look == look { wallpaperNotice = nil }
            return
        }
        wallpaperNotice = WallpaperNotice(look: look, text: text)
        AccessibilityNotification.Announcement(text).post()
    }

    /// The notice popover's binding for `look`'s tile.
    func noticeBinding(_ look: String) -> Binding<WallpaperNotice?> {
        Binding(
            get: { wallpaperNotice?.look == look ? wallpaperNotice : nil },
            set: {
                if $0 == nil, wallpaperNotice?.look == look {
                    wallpaperNotice = nil
                }
            }
        )
    }

    /// One line per screen Use Current Wallpaper skipped; nil where
    /// every screen was stored.
    static func narrate(
        _ outcomes: [Int: CurrentWallpaperOutcome],
        look: String
    ) -> String? {
        let lines = outcomes.sorted { $0.key < $1.key }.compactMap {
            line(for: $0.value, screen: $0.key, look: look)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func line(
        for outcome: CurrentWallpaperOutcome,
        screen: Int,
        look: String
    ) -> String? {
        switch outcome {
        case .stored:
            return nil
        case .notPictureFile:
            return L(
                "looks.wallpaper.current.not_picture",
                "Screen %1$d's wallpaper isn't a picture file, so "
                    + "“%2$@” keeps none for it.",
                screen,
                look
            )
        case .fullScreenSpace:
            return L(
                "looks.wallpaper.current.full_screen",
                "Screen %1$d shows a full-screen app, so “%2$@” keeps "
                    + "what it had for it.",
                screen,
                look
            )
        case .accessRefused:
            return L(
                "looks.wallpaper.current.refused",
                "KiwiDesk wasn't allowed to read Screen %1$d's "
                    + "wallpaper. Use %2$@ instead.",
                screen,
                chooseLabel
            )
        case .unreadable:
            return L(
                "looks.wallpaper.current.unreadable",
                "Screen %1$d's wallpaper couldn't be read. Use "
                    + "%2$@ instead.",
                screen,
                chooseLabel
            )
        }
    }

    /// The menu item a skipped screen is sent to, by its own key.
    private static var chooseLabel: String {
        L("looks.wallpaper.choose", "Choose Wallpaper…")
    }

    private func chooseMessage(for look: ShelfLook) -> String {
        var lines: [String] = []
        if (look.wallpaper?.count ?? 0) > 1 {
            lines.append(
                L(
                    "looks.wallpaper.replaces_all",
                    "This replaces the wallpapers for every screen in "
                        + "“%1$@”.",
                    look.name
                )
            )
        }
        lines.append(
            L(
                "looks.wallpaper.choose_message",
                "Choose the wallpaper for “%1$@”.",
                look.name
            )
        )
        lines.append(
            L(
                "looks.wallpaper.reach",
                "Whenever this look is applied — by you, or by "
                    + "switching to a profile or Desktop that uses it "
                    + "— it sets the wallpaper on each screen's "
                    + "current Desktop. KiwiDesk can't bring back the "
                    + "wallpaper it replaces."
            )
        )
        return lines.joined(separator: " ")
    }

    private enum LargeAnswer { case copy, shrink, cancel }

    /// The over-32 MB question, an alert (#3478 ▸ Size).
    private func askLargeWallpaper(_ data: Data) -> LargeAnswer {
        let alert = NSAlert()
        alert.messageText = L(
            "looks.wallpaper.large.title",
            "This picture is large"
        )
        var body = L(
            "looks.wallpaper.large.body",
            "KiwiDesk keeps a copy in its config folder, which may "
                + "sync to your other Macs or sit in a dotfiles "
                + "repository."
        )
        if WallpaperShrink.isDynamic(data) {
            body +=
                " "
                + L(
                    "looks.wallpaper.large.dynamic",
                    "Shrinking a dynamic wallpaper keeps only one of its "
                        + "pictures."
                )
        }
        alert.informativeText = body
        alert.addButton(
            withTitle: L("looks.wallpaper.large.copy", "Copy Anyway")
        )
        alert.addButton(
            withTitle: L("looks.wallpaper.large.shrink", "Shrink First")
        )
        alert.addButton(withTitle: L("looks.wallpaper.large.cancel", "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .copy
        case .alertSecondButtonReturn: return .shrink
        default: return .cancel
        }
    }

    /// Downscaled to the largest connected screen.
    private func shrink(_ data: Data) -> Data? {
        let pixels =
            NSScreen.screens.map {
                Int(
                    max($0.frame.width, $0.frame.height)
                        * $0.backingScaleFactor
                )
            }.max() ?? 6016
        return WallpaperShrink.shrunk(data, maxPixels: pixels)
    }

    private var unreadableWallpaper: String {
        L(
            "looks.wallpaper.unreadable",
            "KiwiDesk couldn't keep that wallpaper."
        )
    }
}

/// A wallpaper action's refusal, anchored on the tile it was about
/// (#3699).
struct WallpaperNotice: Identifiable, Equatable {
    let id = UUID()
    let look: String
    let text: String
}
