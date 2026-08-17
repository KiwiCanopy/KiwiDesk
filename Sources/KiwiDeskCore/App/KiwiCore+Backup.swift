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
        SetupBundle(
            writtenBy: KiwiDeskVersion.semantic,
            config: guiConfigStore.load(),
            profiles: profiles.allProfiles(),
            palettes: paletteLibrary.userPalettes()
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
        guard
            let bundle = try? JSONDecoder().decode(
                SetupBundle.self,
                from: data
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
