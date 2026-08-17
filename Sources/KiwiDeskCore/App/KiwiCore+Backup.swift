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
    /// read hits the file and every write rewrites it — so a
    /// second instance over the same path costs nothing and cannot
    /// disagree with the GUI's. The one live instance otherwise
    /// belongs to `SettingsModel`, which Core cannot see.
    var paletteLibrary: PaletteStore {
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

    /// Writes this install's backup to `url`.
    public func writeBackup(
        to url: URL
    ) throws(SetupBundleError) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportSetup()) else {
            throw .couldNotWrite(name: url.lastPathComponent)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            onLog("backup export failed: \(error)")
            throw .couldNotWrite(name: url.lastPathComponent)
        }
    }

    /// Replaces this install's settings, profiles and palettes
    /// with `bundle`'s, then reloads.
    ///
    /// **Replace, not merge.** The issue's model and the confirm
    /// the user just answered: merging would need a name-collision
    /// policy per profile and per palette, which is real
    /// complexity for a benefit nobody has asked for, and it would
    /// make the result depend on what happened to be on the
    /// destination Mac. What is replaced goes to the Trash first,
    /// so recovery is one drag away — the courtesy
    /// `resetAllSettings` already extends, for the same reason.
    ///
    /// `trash` has no default, exactly as reset's does not: a
    /// defaulted parameter let a bare test call fill the real
    /// Trash with zero red, and that lesson is one file over.
    @discardableResult
    public func restoreSetup(
        from bundle: SetupBundle,
        trash: (URL) throws -> Void
    ) -> Bool {
        var cleared = true
        for url in [
            guiConfigStore.url, profiles.directory,
            paletteLibrary.url,
        ] where FileManager.default.fileExists(atPath: url.path) {
            if !discard(url, trash: trash) { cleared = false }
        }

        // Write the incoming setup before the reload reads it.
        if let config = bundle.config {
            try? guiConfigStore.save(config)
        }
        for profile in bundle.profiles {
            try? profiles.write(profile)
        }
        try? paletteLibrary.replaceUserPalettes(
            with: bundle.palettes
        )

        // Adoption is the one piece of live profile state the
        // incoming config cannot speak for: it records which
        // profile this Mac matched, which the backup's profiles
        // have just replaced.
        profiles.resetAdoption()

        // Reload first, THEN apply — the order the adopt path
        // already uses, and for the same stated reason: the reload
        // resets the sparse tiling state, so the config's tiling
        // has to go back on top of it rather than under it.
        //
        // `loadConfig` alone is NOT enough, which is the whole
        // reason this call is here. It registers rules and
        // keybindings from the sidecar and runs `init.lua`, but
        // nothing in it pushes the sidecar's `settings`, space
        // modes, pins or Main role into the running core —
        // `applyProfileScopedState` is the function whose job that
        // is, and the GUI's own save path calls it separately for
        // exactly this reason. An earlier cut of this file
        // hand-rolled a prune instead and shipped four defects at
        // once: gaps and layout params never applied, space modes
        // never set, pins and Main dropped, and a space living
        // only in `spaceModes` pruned away. Every one was
        // invisible to a test that read files, and a
        // `guard-prover` round is what asked the question
        // (2026-08-17).
        loadConfig()
        if let config = bundle.config {
            // Ensures and reorders the incoming spaces, prunes the
            // ones the backup never mentions, sets every mode, pin
            // and Main role, re-resolves placement and forces the
            // retile.
            applyProfileScopedState(from: config)
        }
        onLog(
            cleared
                ? "setup restored from backup"
                : "setup restored, but a file could not be removed"
        )
        return cleared
    }

    /// Trash a path, falling back to a hard delete.
    ///
    /// Same argument as reset's: a surviving `gui.json` would flip
    /// the reload back onto the OLD sidecar and turn a confirmed
    /// replace into a silent no-op, which is strictly worse than
    /// skipping the Trash courtesy.
    private func discard(
        _ url: URL,
        trash: (URL) throws -> Void
    ) -> Bool {
        do {
            try trash(url)
            return true
        } catch {
            onLog(
                "restore: could not trash "
                    + "\(url.lastPathComponent) (\(error)); "
                    + "deleting instead"
            )
            do {
                try FileManager.default.removeItem(at: url)
                return true
            } catch {
                onLog(
                    "restore: could not delete "
                        + "\(url.lastPathComponent): \(error)"
                )
                return false
            }
        }
    }
}
