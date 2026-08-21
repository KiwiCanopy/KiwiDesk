import Foundation

/// Export and restore a whole KiwiDesk setup (#606).
///
/// The read half is trivial; the write half is not, and the
/// ordering below is the part to leave alone. `KiwiCore+Reset`
/// paid for it once already: **live state has to be pruned before
/// the reload**, because the config paths capture live state on
/// the way through, so writing files and reloading is not on its
/// own enough to stop the previous setup reappearing.
extension KiwiCore {
    /// The palette library, built on demand.
    ///
    /// Not a stored property: `PaletteStore` is stateless — every
    /// read hits the file and every write rewrites it — so
    /// building one per use costs nothing.
    ///
    /// `public` so there is ONE owner rather than two. It was
    /// internal at first, which left `SettingsModel` constructing
    /// its own store over the same path — a second construction
    /// that existed because of an access modifier rather than a
    /// design decision (`architect-reviewer`, 2026-08-17).
    public var paletteLibrary: PaletteStore {
        PaletteStore(directory: configDirectory)
    }

    /// Everything this install would put in a backup.
    ///
    /// Reads the stores rather than the directory — the
    /// allow-list argument is `SetupBundle`'s.
    public func exportSetup() -> SetupBundle {
        // Each field asks the register whether it travels, so
        // `travelsInABackup` is the switch rather than a comment
        // beside one: flip a case to `false` and it stops being
        // exported, stops being discarded and stops being written,
        // which is what "does not travel" has to mean to be worth
        // recording (`architect-reviewer`, 2026-08-17).
        SetupBundle(
            writtenBy: KiwiDeskVersion.semantic,
            config: ConfigArtifact.guiConfig.travelsInABackup
                ? guiConfigStore.load() : nil,
            profiles: ConfigArtifact.profiles.travelsInABackup
                ? profiles.allProfiles() : [],
            palettes: ConfigArtifact.palettes.travelsInABackup
                ? paletteLibrary.userPalettes() : []
        )
    }

    /// Decodes a backup from `url` without applying any of it.
    ///
    /// Separate from `restore` on purpose: the GUI has to be able
    /// to say "that is not a backup" **before** it asks the user
    /// to confirm replacing everything they have. A confirm
    /// dialog for a restore that will fail on the first read is a
    /// dialog that should never have opened.
    public func readBackup(
        at url: URL
    ) throws(SetupBundleError) -> SetupBundle {
        guard let data = try? Data(contentsOf: url) else {
            throw .unreadable
        }
        let decoder = JSONDecoder()
        // `.iso8601` both ways, matching `ProfileManager` and every
        // other JSON this app writes. The default strategy would
        // put `saved_at` in a backup as a raw epoch number while
        // the same field in every profile file reads
        // "2026-08-16T20:45:13Z" — self-consistent, and wrong for
        // the one artifact whose whole justification is a human
        // opening it. Found by hand-writing a backup and watching
        // the app refuse it.
        decoder.dateDecodingStrategy = .iso8601
        // A bundle carries `[Profile]` inline, so it is the second
        // reader of profile JSON — and backups shipped IN v0.9.7,
        // whose profiles all carry the retired `app_bar.content`
        // (`ConfigMigration`). Without this the bundle decode
        // fails and the user is told `.notABackup` — "that file
        // isn't a KiwiDesk backup" — about a file this app wrote
        // one version ago.
        //
        // In memory only, deliberately: a backup is the user's
        // artifact and a record of a moment, it may sit on
        // read-only media, and rewriting one would edit the thing
        // it exists to preserve. That also makes this the
        // unforgiving side of the crossing — a profile file is
        // repaired and retried next launch, while a refused
        // backup is refused forever.
        let payload =
            ConfigMigration.migratingRetiredBarContent(data)
            ?? data
        guard
            let bundle = try? decoder.decode(
                SetupBundle.self,
                from: payload
            )
        else {
            throw .notABackup
        }
        guard bundle.isReadable else {
            throw .newerFormat(
                found: bundle.format,
                supported: SetupBundle.currentFormat
            )
        }
        guard !bundle.isEmpty else { throw .empty }
        return bundle
    }

    /// Writes this install's backup to `url`, **header first**.
    ///
    /// `.sortedKeys` is the house style for every JSON this app
    /// writes (`GuiConfigStore`, `PaletteStore`) and it buys the
    /// property that makes backups comparable: two exports of one
    /// setup are byte-identical, so a diff shows real change. Its
    /// cost is that it sorts the TOP level too, which put
    /// `writtenBy` — the field that exists for a human opening the
    /// file — on the last line of 263 (owner, 2026-08-17).
    ///
    /// `outputFormatting` is global to an encoder, so the two
    /// cannot be had at once from one encode. Encoding the
    /// subtrees and composing the outer document by hand gets
    /// both: sorted, deterministic subtrees under a header a
    /// reader meets first.
    ///
    /// The drift this invites — a sixth property the composer
    /// forgets — is guarded by
    /// `SetupBundleTests.theAllowListIsPinned`, which compares the
    /// written file against the type's stored properties by
    /// reflection. It has to be reflection: asserting the file's
    /// keys alone catches only what the composer ADDS, and
    /// re-encoding the struct does not help either, because
    /// `JSONEncoder` omits a nil Optional. Both weaker versions
    /// were written and both were proven blind before this one.
    public func writeBackup(
        to url: URL
    ) throws(SetupBundleError) {
        // A sidecar that exists but will not decode is the one
        // case where a silent omission is worst: the user is
        // making a backup because they are about to need it.
        if guiConfigStore.exists, guiConfigStore.load() == nil {
            throw .unreadableSettings
        }
        guard let data = encodedBackup() else {
            throw .couldNotWrite(name: url.lastPathComponent)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            onLog("backup export failed: \(error)")
            throw .couldNotWrite(name: url.lastPathComponent)
        }
    }

    /// The bundle as it is written: header, then payload.
    func encodedBackup() -> Data? {
        /// Just the two scalars, so their JSON literals — and the
        /// string's escaping — come from the encoder rather than
        /// from hand-written quoting.
        struct Header: Encodable {
            let format: Int
            let writtenBy: String
        }
        let bundle = exportSetup()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Paired with the decoder's strategy above; the two must
        // not drift, which `SetupBundleTests.datesAreReadable`
        // pins from the written file.
        encoder.dateEncodingStrategy = .iso8601
        guard
            let head = try? encoder.encode(
                Header(
                    format: bundle.format,
                    writtenBy: bundle.writtenBy
                )
            ),
            let config = try? encoder.encode(bundle.config),
            let profiles = try? encoder.encode(bundle.profiles),
            let palettes = try? encoder.encode(bundle.palettes)
        else { return nil }

        // The header's own braces come off; its two lines lead.
        let headLines = String(decoding: head, as: UTF8.self)
            .split(separator: "\n")
            .dropFirst()
            .dropLast()
            .joined(separator: "\n")
        let body = [
            ("config", config),
            ("profiles", profiles),
            ("palettes", palettes),
        ]
        .map { name, data in
            "  \"\(name)\" : \(reindented(data))"
        }
        .joined(separator: ",\n")
        return Data(
            ("{\n" + headLines + ",\n" + body + "\n}\n").utf8
        )
    }

    /// A pretty-printed subtree, shifted one level in so it sits
    /// correctly under the outer object.
    private func reindented(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { line in
                // A blank line stays blank: the encoder writes one
                // inside an empty container, and padding it leaves
                // trailing whitespace in the shipped file.
                guard line.offset > 0, !line.element.isEmpty else {
                    return String(line.element)
                }
                return "  " + line.element
            }
            .joined(separator: "\n")
    }
}
