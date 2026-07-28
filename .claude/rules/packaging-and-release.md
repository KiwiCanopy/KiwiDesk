---
paths:
  - "scripts/build-app.sh"
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
a raise to macOS 15 touches all three. Both copies fail silently,
but only the plist's does so dangerously (an app declaring a lower
minimum than it runs on, versus a wrong rendition set).

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
`.zip`, a Sparkle delta).

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
