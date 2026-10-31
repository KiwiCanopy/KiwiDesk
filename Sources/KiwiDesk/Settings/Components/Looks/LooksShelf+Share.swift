import AppKit
import KiwiDeskCore
import SwiftUI

/// Share current look… (#1740 ▸ Share): a name popover, then the
/// gallery's submission form in the browser with the current look
/// prefilled.
extension LooksShelf {
    var shareButton: some View {
        Button {
            shareRequest = NameEditRequest(seed: shareSeed)
        } label: {
            Label(
                L("looks.share", "Share current look…"),
                systemImage: "square.and.arrow.up"
            )
        }
        .settingsActionButton()
        .controlSize(.small)
        .popover(item: $shareRequest) { request in
            sharePopover(request)
                .settingsPopoverChrome()
        }
    }

    private func sharePopover(_ request: NameEditRequest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("looks.share.title", "Share current look"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                HelpButton(
                    explanation: L(
                        "looks.share.help",
                        "Opens the gallery's submission form in your "
                            + "browser with your current look filled in. "
                            + "While at "
                            + "least half of a look you imported is "
                            + "unchanged, sharing credits its author. A "
                            + "look you started from a bundled one "
                            + "credits no one."
                    ),
                    subject: L("looks.share.title", "Share current look")
                )
            }
            .padding([.horizontal, .top], 12)
            NameEditPopover(
                seed: request.seed,
                placeholder: Self.namePlaceholder,
                confirmLabel: { _ in L("looks.share.confirm", "Share") },
                isValid: { !trimmed($0).isEmpty },
                notice: { _ in creditLine }
            ) { name in
                shareLook(trimmed(name))
            }
        }
    }

    /// The credit the share carries, as one line; nil without one.
    private var creditLine: String? {
        let share = LookShare(name: "", settings: model.config.settings)
        guard let credit = share.credit,
            let name = credit.name ?? credit.id
        else { return nil }
        guard let author = credit.author else {
            return L("looks.share.based_on_name", "Based on %1$@", name)
        }
        return L(
            "looks.share.based_on",
            "Based on %1$@ by %2$@",
            name,
            author
        )
    }

    private var shareSeed: String {
        model.config.settings.lookOrigin?.name
            ?? L("looks.default_name", "My Look")
    }

    /// Opens the form with the file inside, or — past the address
    /// limit — writes the file, shows it in Finder and opens the
    /// form for the file to be attached.
    private func shareLook(_ name: String) {
        let share = LookShare(name: name, settings: model.config.settings)
        let version = KiwiDeskVersion.semantic
        shareRequest = nil
        do {
            failure = nil
            if let url = try share.prefilledURL(version: version) {
                NSWorkspace.shared.open(url)
                return
            }
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName(name))
            try share.fileData().write(to: file, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([file])
            NSWorkspace.shared.open(share.formURL(version: version))
        } catch {
            failure = L(
                "looks.share_failed",
                "KiwiDesk couldn't prepare this look for sharing."
            )
        }
    }
}

extension LooksShelf {
    /// `name` as a file name: a path separator would name a folder.
    func fileName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-") + ".json"
    }
}
