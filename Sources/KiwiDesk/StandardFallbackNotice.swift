import AppKit
import KiwiDeskCore
import SwiftUI

/// The screen counts this Mac already showed the Standard notice
/// for (#3646). This Mac's state, never config: it does not travel
/// with the config folder or a backup.
enum StandardFallbackShown {
    static let key = "standard_fallback.shown_counts"

    static func wasShown(_ count: Int, in defaults: UserDefaults) -> Bool {
        shown(in: defaults).contains(count)
    }

    static func markShown(_ count: Int, in defaults: UserDefaults) {
        var counts = shown(in: defaults)
        guard !counts.contains(count) else { return }
        counts.append(count)
        defaults.set(counts, forKey: key)
    }

    private static func shown(in defaults: UserDefaults) -> [Int] {
        (defaults.array(forKey: key) as? [Int]) ?? []
    }
}

/// Answers Escape by closing, as OK does: the notice changes
/// nothing, so every way out is the same.
final class StandardFallbackWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

/// The once-per-count notice that a screen change set up the
/// Standard's Spaces (#3646). It comes forward like the update
/// window, by the owner's ruling, and offers no choice.
@MainActor
final class StandardFallbackNotice: NSObject, NSWindowDelegate {
    private(set) static var open: StandardFallbackNotice?

    let fallback: StandardFallback
    private var window: NSWindow?

    /// Whether the notice for `count` is owed: never while the tour
    /// owns the screen or another notice is up — neither records
    /// the count, so a later change asks again — and never twice
    /// for one count on this Mac.
    static func shouldPresent(
        count: Int,
        tourShowing: Bool,
        noticeShowing: Bool,
        defaults: UserDefaults
    ) -> Bool {
        !tourShowing && !noticeShowing
            && !StandardFallbackShown.wasShown(count, in: defaults)
    }

    static func present(
        _ fallback: StandardFallback,
        tourShowing: Bool,
        defaults: UserDefaults = AppDefaults.store
    ) {
        guard
            shouldPresent(
                count: fallback.screenCount,
                tourShowing: tourShowing,
                noticeShowing: open != nil,
                defaults: defaults
            )
        else { return }
        StandardFallbackShown.markShown(
            fallback.screenCount,
            in: defaults
        )
        let notice = StandardFallbackNotice(fallback)
        open = notice
        notice.show()
    }

    private init(_ fallback: StandardFallback) {
        self.fallback = fallback
    }

    private func show() {
        let window = StandardFallbackWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = StandardFallbackWords.title(fallback.screenCount)
        window.contentView = NSHostingView(
            rootView: LocaleScopedRoot {
                StandardFallbackView(
                    screenCount: fallback.screenCount
                ) { [weak window] in window?.close() }
            }
            .environmentObject(LocalizationManager.shared)
        )
        window.setContentSize(window.contentView?.fittingSize ?? .zero)
        // Above the bars, as the tour is once its grant lands.
        window.level = BarPanel.aboveLevel
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.forceFront(window)
    }

    func windowWillClose(_ notification: Notification) {
        if Self.open === self { Self.open = nil }
    }
}

/// The notice's words, one key per sentence and per plural form.
@MainActor
enum StandardFallbackWords {
    static func title(_ count: Int) -> String {
        count == 1
            ? L("standard_fallback.title.one", "Spaces for 1 Screen")
            : L(
                "standard_fallback.title.many",
                "Spaces for %1$d Screens",
                count
            )
    }

    static func lead(_ count: Int) -> String {
        count == 1
            ? L(
                "standard_fallback.lead.one",
                "KiwiDesk set up Spaces for 1 screen."
            )
            : L(
                "standard_fallback.lead.many",
                "KiwiDesk set up Spaces for %1$d screens.",
                count
            )
    }

    /// Names Settings' own save button through its key, so the
    /// words match the button in every catalog.
    static func body(_ count: Int) -> String {
        let save = L("footer.save_as_new_profile", "Save as New Profile…")
        return count == 1
            ? L(
                "standard_fallback.body.one",
                "Their layouts suit this screen's shape. To keep "
                    + "changes, choose %1$@ in Settings.",
                save
            )
            : L(
                "standard_fallback.body.many",
                "Their layouts suit these screens' shapes. To keep "
                    + "changes, choose %1$@ in Settings.",
                save
            )
    }

    static func help(_ count: Int) -> String {
        count == 1
            ? L(
                "standard_fallback.help.one",
                "Each profile is saved for one screen count. With no "
                    + "profile for 1 screen, KiwiDesk uses its Standard "
                    + "setup: a set of Spaces, each in the layout that "
                    + "suits your screen. Changes stay until you save "
                    + "them as a profile. From then on, that profile "
                    + "loads whenever 1 screen is connected."
            )
            : L(
                "standard_fallback.help.many",
                "Each profile is saved for one screen count. With no "
                    + "profile for %1$d screens, KiwiDesk uses its "
                    + "Standard setup: a set of Spaces, each in the "
                    + "layout that suits your screens. Changes stay "
                    + "until you save them as a profile. From then on, "
                    + "that profile loads whenever %1$d screens are "
                    + "connected.",
                count
            )
    }
}

/// The notice's content: the lead with its help, the body, OK.
struct StandardFallbackView: View {
    let screenCount: Int
    let onOK: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(StandardFallbackWords.lead(screenCount))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HelpButton(
                    explanation: StandardFallbackWords.help(screenCount)
                )
            }
            Text(StandardFallbackWords.body(screenCount))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("standard_fallback.ok", "OK"), action: onOK)
                    .keyboardShortcut(.defaultAction)
                    .settingsActionButton()
            }
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 360)
        .background(SettingsTheme.card)
    }
}
