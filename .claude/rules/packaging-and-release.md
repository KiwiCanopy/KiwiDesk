---
paths:
  - "scripts/build-app.sh"
  - "scripts/release.sh"
  - "scripts/bump-version.sh"
  - "scripts/install-hooks.sh"
  - "scripts/pre-commit"
  - "Package.swift"
  - ".github/workflows/**"
  - "**/ResourceBundle*.swift"
---

# Packaging, signing & release

Canonical for this subsystem (AGENTS.md §5 indexes it).

## Building the `.app`

`./scripts/build-app.sh` (#89). SwiftPM cannot emit a bundle, so
this assembles one from the release build, compiles
`assets/AppIcon.icon` through `actool`, and signs it.

Nothing it writes is a second copy: the version is read from
`KiwiDeskVersion.swift` and the two icon keys come from actool's
own partial plist — though the **deployment target is still typed
in three places** (`Package.swift`, the plist, actool's flag), so
a raise to macOS 15 touches all three, and `Package.swift` is the
one a build actually enforces. The two in the script fail
silently, but only the plist's does so dangerously (an app
declaring a lower minimum than it runs on, versus a wrong
rendition set).

It **discovers the signing identity** from the keychain. That
string is not a secret (any user can read it out of a shipped
binary with `codesign -dv`), so it is never hardcoded to a
developer's name nor passed through a CI secret; only the
certificate is secret, and it lives in the keychain. With no
certificate present it falls back to ad-hoc, so a contributor can
still build. `--identity` overrides; `--notarize <profile>` takes
a `notarytool` keychain profile the developer created themselves.
`--dmg` additionally wraps the result in a disk image for the
website download — the cask installs from a `.zip` and never
needs one.

Signing is inside-out over `Resources/*.bundle` only, so the
first dependency that adds nested code (`Contents/Frameworks/`,
i.e. Sparkle) has to extend that loop — packaging is not "done"
for it.

Whether a built artifact may be *published* is a separate,
product decision: see "No distribution channel without an update
path" in `docs/design-decisions.md`.

## Every distributable artifact needs its OWN ticket

And this cannot be caught on the machine that built it. A disk
image is a separate piece of signed code from the app inside it:
notarizing the app does not cover the `.dmg` carrying it, so
`--notarize --dmg` submits **twice** and staples each.

Like the `Bundle.module` trap below, the build machine is the one
place the failure is invisible — a locally-built image carries no
`com.apple.quarantine` attribute, so it mounts and runs perfectly
here and only says "KiwiDesk is damaged and can't be opened"
after a real download.

**`spctl` is not the check.** `spctl --assess` is satisfied by an
*online* notarization lookup, so it answers `accepted` for an
artifact that was notarized but never stapled — which then fails
on a machine that is offline or behind a captive portal. Only
`xcrun stapler validate` proves the ticket is physically
attached.

**Verify by stamping quarantine on a copy:**

```bash
xattr -w com.apple.quarantine "0081;0;Safari;$(uuidgen)" <artifact>
```

Mount it, then `stapler validate` plus `spctl -a -vvv -t open
--context context:primary-signature` on the image and `-t exec`
on the app inside (image and app need different `spctl`
invocations).

Companion rule: **an archive meant for distribution is created
AFTER stapling, never reused from the notarization payload** —
the zip submitted to Apple is made pre-staple by construction, so
shipping it would strand every user with an unticketed bundle.
Applies to any artifact type added later (`.pkg`, the cask's
`.zip`, a Sparkle delta). `--zip` is the cask's archive and obeys
it: built after step 6, and refusing an unstapled bundle the way
`--dmg` does.

**An archive is the one artifact that carries no ticket of its
own, and that is not a loophole in the rule above.** A disk image
is signed code, so Apple can ticket it; a `.zip` is a container
with nowhere to put a signature, so `stapler` has no target to
staple to. The ticket therefore rides on the `.app` **inside** —
which is exactly why the archive must be built after the staple
rather than before it, and why a `--zip` run that cannot find a
stapled bundle names its output `-unnotarized.zip` instead of
producing something an upload would reach for.

## Cutting a release (#32)

**Cut every release with `scripts/release.sh <version>`.** The
git tag and `KiwiDeskVersion.semantic` are two hand-written copies
of one number, and that script stamps the constant *before*
creating the tag so the two cannot disagree. A tag pushed by hand
ships a binary whose `--version` names a release it is not —
nothing about the artifact looks wrong, and the mistake is only
legible to someone who already knows the real answer. The "Verify
the tag matches the binary" step in
`.github/workflows/release.yml` is the guard; it costs a re-tag
when it fires, against a mislabelled download when it does not
exist.

**A version is three integers — no prerelease suffix.** `0.9.0-rc1`
is valid SemVer and cannot be a `CFBundleVersion`, which takes 1-3
dot-separated integers and nothing else. Both `bump-version.sh`
and `build-app.sh` enforce a shape, and the *narrower* one has to
run first: the packager only sees the version after
`scripts/release.sh` has pushed the tag, and a fetched tag cannot
be withdrawn. So widening what `bump-version.sh` accepts, without
widening what `build-app.sh` can package, buys a release that
fails on the far side of the one irreversible step.
`ScriptStampTests` holds the accepted shape.

**Its verification gate mirrors the `verify-gate` skill, and a
change to one updates the others.** AGENTS.md §3 gives that skill
the procedure, and two ship-grade copies re-state it — the ones
where running a *stale* gate ships an artifact:
`scripts/release.sh` (release build made unconditional) and the
`verify` job in `release.yml`, which re-runs the gate against a
pushed tag — the copy that catches a tag pushed by hand, which
never met the script's (#487; branch protection cannot see tags,
so the workflow is the only gate such a tag passes). Both copies
are pinned to the skill by `VerifyGateParityTests`, which derives
the command list from `SKILL.md` — extend that suite before
shipping a further copy, and at a *third* ship-grade copy weigh
one sealed verify script every copy calls over another scanner
(the same past-two-mirrors escalation parity-tests.md applies to
field lists). (Drift in ci.yml's copy weakens a PR check, not a
release, so it sits outside the suite's ship-grade scope.)

The `verify` job carries one named exemption, which the suite
encodes structurally — its workflow pin scrapes only the skill's
fast-inner-loop section: no `swift build -c release`. The
obligation it leans on — **the release job must keep a
`-c release` compile ahead of any submission or draft**; today
that is `build-app.sh`'s first act — is what lets the pipeline
still refuse a tree that cannot build release without paying the
same compile twice in sequence.

**A job downstream of `verify` checks out
`needs.verify.outputs.sha`, never a ref name.** A tag name is
re-resolved against the remote at each job's own start, so by
name a single-job re-run — or a tag deleted and re-pushed
mid-run — hands the job a tree the gate never saw. The release
job's checkout comment carries the full argument; a future
publish job (a tap bump, a Sparkle appcast) copies its shape,
not ci.yml's `github.ref` template.

**Stamp the commit at build time; never check one in.** A commit
cannot contain its own SHA, so a bump made while the release
commit is still being written can only name that commit's
*parent* — which is what shipped until #32, reliably off by one
and wrong in the direction that looks right. `bump-version.sh`
therefore writes `"unknown"`, and `--stamp-commit` writes the real
one from the workflow, where HEAD *is* the tagged commit. Anything
needing that stamp calls the script: a second `sed` over
`KiwiDeskVersion.swift` would be a second owner of the file's
shape.

**Signing credentials are optional to the workflow, by
construction.** Absent a certificate it falls through to the same
ad-hoc branch a contributor's machine takes, so the pipeline can
be exercised before any credential exists — and the artifact it
produces says `-unnotarized` in its own filename rather than
relying on a log line. As of 2026-07 GitHub does not expose
`secrets` to a step-level `if`, so their presence is lifted into a
step output first; a future gate on a new credential extends that
step rather than reaching for `secrets` in a condition that
silently reads empty.

**Publishing is not this file's call.** The workflow drafts the
release rather than publishing it, and "No distribution channel
without an update path" in `docs/design-decisions.md` owns both
the reason and what a draft does and does not expose. Do not
change that step to publish without changing that entry first —
restating its argument here is how the two copies came to
disagree about a draft's reach on the day they were written.

## Never `Bundle.module` in code that runs from the `.app` (#89)

Go through `ResourceBundle.locate` (`Bundle.kiwiDeskCore` /
`Bundle.kiwiDeskGui`).

SwiftPM's generated accessor searches `Bundle.main.bundleURL`,
which is the executable's directory for a bare binary but the
**bundle root** inside an `.app` — and codesign refuses to seal a
bundle with anything loose there ("unsealed contents present in
the bundle root", `Sealed Resources=none`). So the only location
that accessor accepts is one a distributable app cannot use, and
the resources live in `Contents/Resources` instead.

**The trap is that this cannot be caught on the machine that
built it.** The accessor's second candidate is an absolute path
into the `.build` directory that compiled it, so locally it
always resolves and any layout looks correct; elsewhere — or
after deleting `.build` — it matches neither candidate and calls
`fatalError`. A hard crash at first access, not a quiet fallback
to defaults. Verifying that the files are *present* in the bundle
proves nothing about this; only launching a copy with `.build`
moved aside does.

## Git hooks

`./scripts/install-hooks.sh` once per clone. The `pre-commit`
hook lints staged Swift, runs the locale checks when a catalog is
staged, and **refuses a commit made while HEAD is `main`** —
server-side branch protection is impossible while the repo is
private (GitHub free answers `403 Upgrade to GitHub Pro or make
this repository public`), and the exposure that actually bites is
committing to `main` believing HEAD is a feature branch.

Deliberately the commit, not the push: ff-merging a reviewed
branch legitimately writes to `main`. Override a genuinely
intended one with `KIWIDESK_ALLOW_MAIN_COMMIT=1`, which names the
rule you are skipping instead of `--no-verify` taking the lint
and locale checks with it.

## CI

`.github/workflows/ci.yml` builds, lints, and tests on every push
and on PRs targeting `main`. A red build blocks merging. The
release build runs as a separate, non-blocking job (#532) — when
to run it locally instead is decided by the `verify-gate` skill,
which owns that call.
