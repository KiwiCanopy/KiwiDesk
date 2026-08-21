import AppKit
import Testing

@testable import KiwiDeskCore

/// Accessibility identity of the App Bar items (#901): each item
/// is an accessible button element, its internal drawing subviews
/// stay silent, and its label announces the app, window title, and
/// group count.
@Suite("App bar item accessibility (#901)", .serialized)
@MainActor
struct AppBarAccessibilityTests {
    private func makeView(
        name: String = "Safari",
        text: String = "Downloads",
        count: Int = 1
    ) -> AppBarItemView {
        LocalizationManager.shared.select("en")
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            id: WindowID(1),
            name: name,
            text: text,
            icon: nil,
            glyph: nil,
            count: count,
            active: false,
            horizontal: true,
            style: AppBarStyle()
        )
        view.layout()
        return view
    }

    @Test("App bar item is an accessible button element")
    func itemIsAccessibleButton() {
        let view = makeView()
        #expect(view.isAccessibilityElement())
        #expect(view.accessibilityRole() == .button)
    }

    @Test("Internal drawing subviews stay silent to VoiceOver")
    func subviewsAreSilenced() {
        let view = makeView(count: 2)
        #expect(!view.glyphLabel.isAccessibilityElement())
        #expect(!view.label.isAccessibilityElement())
        #expect(!view.iconView.isAccessibilityElement())
        #expect(!view.badge.isAccessibilityElement())
    }

    @Test("Item with distinct title announces app and window")
    func windowTitleAnnounced() {
        let view = makeView(
            name: "Safari",
            text: "Downloads",
            count: 1
        )
        #expect(
            view.accessibilityLabel() == "Safari, window Downloads"
        )
    }

    @Test("Item with app name only announces app")
    func appNameOnlyWhenNoTitle() {
        let view = makeView(
            name: "Safari",
            text: "Safari",
            count: 1
        )
        #expect(view.accessibilityLabel() == "Safari")
    }

    @Test("Empty title falls back to app name announcement")
    func emptyTitleAnnouncesAppName() {
        let view = makeView(
            name: "Terminal",
            text: "",
            count: 1
        )
        #expect(view.accessibilityLabel() == "Terminal")
    }

    @Test("Collapsed group announces app and window count")
    func groupAnnouncedWithCount() {
        let view = makeView(
            name: "Safari",
            text: "Safari",
            count: 3
        )
        #expect(view.accessibilityLabel() == "Safari, 3 windows")
    }
}
