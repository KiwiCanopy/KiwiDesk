import Foundation

/// Restoring a backup over a live install (#606).
///
/// Split from `KiwiCore+Backup` at §2.1's ceiling, on the seam the
/// feature already has: that file reads THIS install and writes a
/// file, this one takes a file and replaces this install. Named
/// `+BackupRestore` rather than `+Restore` because
/// `KiwiCore+Restore` is taken by snapshot restore — replaying
/// saved window state after wake or a crash — which is a different
/// subject entirely.
///
/// The ordering below is the part to leave alone. A `guard-prover`
/// round and the owner's own device each found what it costs to
/// get wrong, and the comments say which.
extension KiwiCore {
    /// Replaces this install's settings, profiles and palettes
    /// with `bundle`'s, then reloads.
    ///
    /// **Replace, not merge.** Merging would need a name-collision
    /// policy per profile and per palette — real complexity for a
    /// benefit nobody asked for, and it would make the result
    /// depend on what happened to be on the destination Mac, which
    /// is the variable a person carrying a backup wants removed.
    /// What is replaced goes to the Trash first, so recovery is
    /// one drag away.
    ///
    /// `trash` has no default, exactly as reset's does not: a
    /// defaulted parameter let a bare test call fill the real
    /// Trash with zero red, and that lesson is one file over.
    ///
    /// **Throws rather than reporting a Bool.** A write that fails
    /// after the originals are in the Trash is the one failure
    /// class the pre-flight `readBackup` cannot catch, and an
    /// earlier cut swallowed all three writes with `try?` while
    /// the caller discarded the Bool — the user would have been
    /// told nothing at all.
    @discardableResult
    public func restoreSetup(
        from bundle: SetupBundle,
        trash: (URL) throws -> Void
    ) throws(SetupBundleError) -> RestoreOutcome {
        // **Refuse before touching anything** when this Mac's
        // config is Lua-owned and the backup carries settings.
        // `loadConfig` would take the `applyConfigGlobals` branch,
        // so the written `gui.json`'s rules and keybindings would
        // never be read while the profile-scoped half applied
        // anyway — a half-landed restore reporting success
        // (`architect-reviewer`, 2026-08-17). Checked here rather
        // than in `readBackup` because it is a property of the
        // DESTINATION, not of the file: the same backup restores
        // cleanly onto a GUI-managed Mac, so it must not be
        // refused at read time.
        if bundle.config != nil, !isGuiManaged {
            throw .luaOwnsThisMac
        }

        // **Only discard what this bundle can replace.** A bundle
        // with no config — a Lua-owned export — must not take the
        // destination's `gui.json` with it: the write below is
        // guarded by the same `if let`, so trashing it
        // unconditionally left nothing to reload from, and
        // `loadConfig` then reseeded a sidecar from live state
        // that `resetDeclarativeState` had already flattened —
        // every space back to `.bsp`, app rules gone, shortcuts
        // back to the starter set, all persisted. A restore that
        // supplied no settings would have silently destroyed the
        // ones already there (`code-reviewer`, 2026-08-17).
        // **A removal that failed is a failed restore, not a
        // footnote.** If the profiles directory survives both the
        // trash and the hard delete, the bundle's profiles are
        // written ALONGSIDE the destination's and a documented
        // replace becomes a silent merge — nothing thrown, nothing
        // logged. Converting this function to throwing dropped the
        // Bool that used to carry that outcome, so the answer is
        // now to refuse before anything is written rather than to
        // report it afterwards (`architect-reviewer`, 2026-08-17).
        // Reads `travelsInABackup` as well as the payload, which
        // is what makes that property load-bearing rather than
        // documentation with a test attached: a case flipped to
        // `false` stops being discarded and stops being written,
        // which is the whole meaning of not travelling.
        let replacing = ConfigArtifact.allCases.filter {
            $0.travelsInABackup && bundle.replaces($0)
        }
        guard
            discardArtifacts(
                replacing,
                reason: "restore",
                trash: trash
            )
        else {
            throw .couldNotWrite(
                name: profiles.directory.lastPathComponent
            )
        }

        let outcome = try writeIncoming(bundle)

        // Adoption is the one piece of live profile state the
        // incoming config cannot speak for: it records which
        // profile this Mac matched, which the backup's profiles
        // have just replaced.
        profiles.resetAdoption()

        // The destination's remembered arrangement names spaces
        // that no longer exist — the restore just replaced the
        // space list. `resetAllSettings` discards it for exactly
        // this reason, and `CrashRecovery` names the harm: a stale
        // snapshot files new windows into old spaces and seeds
        // dead ids into the remembered-space map. The snapshot
        // rightly does not TRAVEL in a bundle; that is a different
        // question from whether the destination's own survives a
        // confirmed replace, and it must not.
        discardSavedArrangement()

        // Reload first, THEN apply — the order the adopt path
        // already uses, and for its stated reason: the reload
        // resets the sparse tiling state, so the config's tiling
        // belongs on top of it rather than under it.
        //
        // `loadConfig` alone is NOT enough. It registers rules and
        // keybindings from the sidecar and runs `init.lua`, but
        // nothing in it pushes the sidecar's `settings`, space
        // modes, pins or Main role into the running core —
        // `applyProfileScopedState` is the function whose job that
        // is, and the GUI's own save path calls it separately for
        // exactly this reason. An earlier cut hand-rolled a prune
        // instead and shipped four defects at once: gaps and
        // layout params never applied, space modes never set, pins
        // and Main dropped, and a space living only in
        // `spaceModes` pruned away. Every one was invisible to a
        // test that read files.
        loadConfig()
        if let config = bundle.config {
            applyProfileScopedState(from: config)
        }

        // Then a profile on top, which is what the cascade means
        // and what a restore is incomplete without.
        //
        // **This is where a restore differs from a save.** A save
        // applies to a core that already HAS an adopted profile,
        // while a restore has just replaced every profile on disk
        // and adopted none. `loadConfig`'s own
        // `reapplyActiveProfileState` then has nothing to reapply,
        // and the seed/adopt path is skipped because `gui.json`
        // was written before the reload — so without this call the
        // only adopter never runs.
        //
        // The symptom is not subtle and the owner met it within
        // minutes: space modes live in the PROFILE, not in
        // `gui.json`, so every space fell to the `?? .bsp` default
        // and a restored setup came back with every layout wrong.
        // The Layout submenu's save row vanished with it
        // (`activeProfileName != nil`).
        //
        // Adopting by the DESTINATION's screens rather than
        // re-adopting whatever the source Mac had is the point of
        // a migration: the incoming profiles are on disk now, and
        // this picks the one matching the monitors actually in
        // front of the user (#7's binding wins first, then #36's
        // resolution order).
        handleMonitorChange()
        // Explicit apply, so it forces (§5): the un-forced retile
        // inside the adoption path would be swallowed by the
        // engine's ±2 pt "already there" tolerance for the small
        // moves a settings change makes.
        retile(force: true)
        onLog(
            outcome.isClean
                ? "setup restored from backup"
                : "setup restored, skipping "
                    + "\(outcome.skippedProfiles.count) profile(s) "
                    + "and \(outcome.refusedPalettes) palette(s)"
        )
        return outcome
    }

    /// Writes the bundle's three payloads, reporting what it could
    /// not take.
    ///
    /// The one phase worth extracting from the sequence above: its
    /// internal order does not matter relative to the rest, it
    /// either lands or throws, and pulling it out is what gives
    /// the skipped-profile information somewhere to live
    /// (`architect-reviewer`, 2026-08-17). The rest of
    /// `restoreSetup` stays one ordered transaction on purpose —
    /// five private phases would make calling them out of order
    /// expressible, which is the hazard three separate defects
    /// have already come from.
    ///
    /// **Each write names its own file when it fails**; an earlier
    /// cut reported `gui.json` for all three.
    ///
    /// **And a single bad profile is skipped, not fatal.** A
    /// hand-edited bundle can carry a name `ProfileManager`
    /// rejects, and aborting there left the destination with its
    /// config in the Trash and nothing loaded — the worst outcome
    /// available, strictly worse than finishing or refusing up
    /// front.
    private func writeIncoming(
        _ bundle: SetupBundle
    ) throws(SetupBundleError) -> RestoreOutcome {
        if let config = bundle.config {
            do {
                try guiConfigStore.save(config)
            } catch {
                onLog("restore: gui.json write failed: \(error)")
                throw .couldNotWrite(
                    name: guiConfigStore.url.lastPathComponent
                )
            }
        }
        var skipped: [String] = []
        for profile in bundle.profiles {
            do {
                try profiles.write(profile)
            } catch {
                skipped.append(profile.name)
                onLog(
                    "restore: skipped profile "
                        + "'\(profile.name)': \(error)"
                )
            }
        }
        // Every profile failing is not a skip, it is a failed
        // restore — and it is distinguishable from a bundle that
        // carried none, which is legal.
        if !bundle.profiles.isEmpty,
            skipped.count == bundle.profiles.count
        {
            throw .couldNotWrite(
                name: profiles.directory.lastPathComponent
            )
        }
        var refused = 0
        if !bundle.palettes.isEmpty {
            do {
                refused = try paletteLibrary.replaceUserPalettes(
                    with: bundle.palettes
                )
            } catch {
                onLog("restore: palettes write failed: \(error)")
                throw .couldNotWrite(
                    name: paletteLibrary.url.lastPathComponent
                )
            }
        }
        return RestoreOutcome(
            skippedProfiles: skipped,
            refusedPalettes: refused
        )
    }
}
