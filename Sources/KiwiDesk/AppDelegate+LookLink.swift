import AppKit
import KiwiDeskCore

/// The gallery's "Add to KiwiDesk" links (#1740 ▸ Step 3 decisions):
/// `kiwidesk://look/<id>` downloads that one look, adds it to My
/// looks under a free name and wears it as an unsaved Settings
/// change. Nothing is saved without the user.
extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for link in urls.compactMap(LookLink.init) {
            Task { await addLinkedLook(link) }
        }
    }

    private func addLinkedLook(_ link: LookLink) async {
        do {
            let data = try await link.fetch {
                try await URLSession.shared.data(for: $0)
            }
            let look = try core.installGalleryLook(
                data,
                from: link,
                fallbackName: L("looks.default_name", "My Look")
            )
            dashboard.show()
            dashboard.model.wearLinkedLook(look)
        } catch {
            Self.refuseLinkedLook(Self.linkFailure(error))
        }
    }

    /// The sentence for why a link added no look.
    static func linkFailure(_ error: any Error) -> String {
        switch error {
        case LookLink.Failure.unreachable:
            return L(
                "looks.link_unreachable",
                "KiwiDesk couldn't download the look. Check your "
                    + "connection and try again."
            )
        case LookLink.Failure.missing:
            return L(
                "looks.link_missing",
                "The gallery no longer has this look."
            )
        case LookStore.StoreError.newerLookFile:
            return L(
                "looks.import_newer",
                "This look was made by a newer KiwiDesk. "
                    + "Update KiwiDesk to import it."
            )
        case LookLink.Failure.invalid, LookStore.StoreError.invalidFile:
            return L(
                "looks.link_invalid",
                "The gallery sent a file that isn't a KiwiDesk look."
            )
        default:
            return L(
                "looks.link_library",
                "KiwiDesk couldn't add the look to My looks."
            )
        }
    }

    private static func refuseLinkedLook(_ reason: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "looks.link_failed",
            "Couldn't add this look"
        )
        alert.informativeText = reason
        NSApp.activate()
        alert.runModal()
    }
}
