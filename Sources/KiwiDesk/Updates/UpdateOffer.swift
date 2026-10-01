import Foundation
import Sparkle

/// What the update window says about the offer, fixed for its
/// lifetime (#1542).
struct UpdateOffer {
    /// The offered version, as displayed.
    let version: String
    /// The offered `sparkle:version` — what Sparkle compares.
    let build: String
    /// The running version, as displayed.
    let installed: String
    let released: Date?
    /// Nil when the offered version's notes cannot be read.
    let digest: UpdateNotesDigest?

    /// A version's full release notes on GitHub.
    static func notesURL(for version: String) -> URL {
        SupportLinks.releases
            .appendingPathComponent("tag")
            .appendingPathComponent("v" + version)
    }

    /// The offer and its notes merged across every loaded item.
    /// Versions compare as Sparkle compares them —
    /// `sparkle:version` against the host's `CFBundleVersion` —
    /// and display as `CFBundleShortVersionString`.
    static func make(
        item: SUAppcastItem,
        loaded: [SUAppcastItem],
        host: Bundle
    ) -> UpdateOffer {
        let installed =
            host.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? ""
        let shown =
            host.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? installed
        let comparator = SUStandardVersionComparator.default
        let sources = (loaded + [item]).map {
            UpdateNotesDigest.Source(
                version: $0.versionString,
                notes: $0.propertiesDictionary[ReleaseNotes.element]
                    as? String
            )
        }
        return UpdateOffer(
            version: item.displayVersionString,
            build: item.versionString,
            installed: shown,
            released: item.date,
            digest: UpdateNotesDigest.make(
                sources: sources,
                installed: installed,
                offered: item.versionString,
                compare: comparator.compareVersion(_:toVersion:)
            )
        )
    }

    /// The running version's own notes, for the window's "up to
    /// date" answer (#1849); no digest when the feed does not list
    /// this build.
    static func current(
        loaded: [SUAppcastItem],
        host: Bundle
    ) -> UpdateOffer {
        let build =
            host.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? ""
        let shown =
            host.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? build
        let item = loaded.first { $0.versionString == build }
        let digest = item.flatMap {
            UpdateNotesDigest.make(
                sources: [
                    UpdateNotesDigest.Source(
                        version: $0.versionString,
                        notes: $0.propertiesDictionary[ReleaseNotes.element]
                            as? String
                    )
                ],
                installed: nil,
                offered: build,
                compare: SUStandardVersionComparator.default
                    .compareVersion(_:toVersion:)
            )
        }
        return UpdateOffer(
            version: shown,
            build: build,
            installed: shown,
            released: item?.date,
            digest: digest
        )
    }

    /// "What's new" for the running version, merged across every
    /// feed item after `since`; nil when the running version's
    /// own notes cannot be read.
    static func whatsNew(
        items: [WhatsNewFeed.Item],
        since: String?,
        current: String
    ) -> UpdateOffer? {
        guard let item = items.first(where: { $0.version == current })
        else { return nil }
        let digest = UpdateNotesDigest.make(
            sources: items.map {
                UpdateNotesDigest.Source(version: $0.version, notes: $0.notes)
            },
            installed: since,
            offered: current,
            compare: SUStandardVersionComparator.default
                .compareVersion(_:toVersion:)
        )
        guard let digest else { return nil }
        return UpdateOffer(
            version: item.shown,
            build: item.version,
            installed: since ?? "",
            released: item.released,
            digest: digest
        )
    }
}
