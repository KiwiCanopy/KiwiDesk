import KiwiDeskCore
import SwiftUI

/// An Apps-card row's Auto-open checkbox (#3122, #2439): off by default,
/// greyed with its reason where Core says it cannot open the app.
struct KiwiVisionLensAutoOpenToggle: View {
    let lens: VisionLens
    let app: String
    let set: (Bool) -> Void

    var body: some View {
        let block = lens.autoOpenBlock(app)
        let name = KeybindingCatalog.displayName(forBundleID: app)
        let hint = KiwiVisionLensAutoOpenWords.hint(name)
        Toggle(
            KiwiVisionLensAutoOpenWords.title,
            isOn: Binding(
                get: { block == nil && lens.openApps.contains(app) },
                set: { on in set(on) }
            )
        )
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .disabled(block != nil)
        .help(block.map(KiwiVisionLensAutoOpenWords.blocked) ?? hint)
        .accessibilityHint(
            block.map(KiwiVisionLensAutoOpenWords.blocked) ?? hint
        )
    }
}

/// The Auto-open checkbox's words, one home for the drawn and the
/// spoken form.
@MainActor
enum KiwiVisionLensAutoOpenWords {
    static var title: String {
        L("kiwivision.lens.apps.auto_open", "Auto-open")
    }

    static func hint(_ app: String) -> String {
        L(
            "kiwivision.lens.apps.auto_open.help",
            "When this lens turns on and %1$@ has no window open, "
                + "KiwiDesk opens one.",
            app
        )
    }

    static func blocked(_ block: AutoOpenBlock) -> String {
        switch block {
        case .titled:
            return L(
                "kiwivision.lens.apps.auto_open.titled",
                "A new window would not match the title and would stay "
                    + "hazed. Choose %1$@ to open one.",
                KiwiVisionLensWords.allWindows
            )
        case .noBundleID:
            return L(
                "kiwivision.lens.apps.auto_open.no_bundle",
                "KiwiDesk opens only an app it knows by its bundle ID."
            )
        }
    }
}
