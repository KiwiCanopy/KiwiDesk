---
paths:
  - "scripts/build-app.sh"
  - "scripts/appcast-sync"
  - "scripts/changelog-sync"
  - "scripts/protect-main.sh"
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


## The architecture claim travels with the build

**A published requirement naming an architecture is a claim about
the artifact, so it moves in the same change set as anything that
could change what the artifact runs on.** Since #904 several
surfaces say *Apple silicon* — find them with
`grep -rn "Apple silicon" README.md docs/ site/src/`, rather
than trusting a list here that drifts the moment a seventh
surface says it. They say it because `build-app.sh` passes no
arch flag while the release workflow builds on an arm64 runner —
two facts with nothing connecting them and no guard over
either.

The asymmetry is what earns the rule. While the cask was the only
install path its `depends_on arch: :arm64` refused an Intel
machine outright; a promoted download has no such gate, so the
sentence on the page IS the gate. Ship a universal binary and six
places quietly under-promise; move to an Intel runner and they
lie, in the direction that hands a stranger an app that will not
launch.

So: changing the arch the release builds for is not done until
those readers are changed with it. `docs/design-decisions.md` ▸
*Two install paths* owns why the download exists; this owns what
it must keep telling the truth about.

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

**The plist must declare `CFBundleLocalizations`, derived from
`Sources/KiwiDeskCore/Resources/Locales`.** A bundle that names
one localization gets that one back: macOS resolves the process
locale to `CFBundleDevelopmentRegion` and every shipped catalog
becomes unreachable except by picking it by hand in Settings
(#659). Nothing crashes and nothing logs, and it cannot reproduce
under `swift run`, which has no plist at all — so the only signal
is a user reporting the app is English. `AppPlistLocalizationTests`
holds both halves: that the key is there, and that its array is
the glob's expansion rather than a typed list that would go stale
on the next locale.

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

**Signing is inside-out over the whole nest, and the order is
the obligation.** The bundle carries `Resources/*.bundle` and,
since #874, `Contents/Frameworks/Sparkle.framework` — which is
itself four signable pieces (both XPC services, `Autoupdate`,
`Updater.app`) before the framework, before the app. Every rule
below is held by `SparklePackagingTests`, which pins the order in
the script rather than the behaviour, a shell script being
untestable without a signing identity:

- **A nested piece that is missing is a hard error, never a
  skip.** The set is stable for a Sparkle version, so an absent
  one means the layout moved on a bump — and a loop that quietly
  signs three of four ships an app that fails notarization days
  later, from a build that verified perfectly here.
- **The framework is copied and the executable's rpath written
  BEFORE any signing.** `install_name_tool` rewrites the Mach-O
  load commands, so running it afterwards invalidates the
  signature it comes after. SwiftPM links Sparkle and embeds
  nothing, so a bundle without that copy launches and dies on a
  missing `@rpath`.
- **A vendor framework's own signature is not something to
  preserve.** Sparkle ships ad-hoc signed with no Team ID
  (checked against 2.9.6, both distributions), so ours is the
  only real signature the nest gets. A future dependency that
  arrives properly signed is a different case — weigh it then
  rather than inheriting this sentence.

**`SUFeedURL` and `SUPublicEDKey` are permanent from the first
build that ships them.** An installed copy looks at no other feed
and trusts no other key, so changing either reaches nobody who
has not already updated — and losing the EdDSA private half
strands every installed copy with no recovery. It belongs
wherever the Developer ID certificate belongs, and in the
`SPARKLE_PRIVATE_KEY` actions secret. **Leave
`SUEnableAutomaticChecks` set.** `docs/design-decisions.md` ▸
*Background update checks are on, and there is no switch* is the
ruling, and unsetting the key is what changes it.

**A build must not ship a feed URL that 404s.** The plist keys
and the appcast that answers them are one shipping decision, so a
release cut between the two halves advertises an update channel
that errors on click. Either both are in the tag, or neither.
So a feed with no offerable release renders an itemless channel
rather than no file: an itemless channel is a well-formed
"nothing newer" — confirmed against Sparkle 2.9.6, whose
`SUAppcast` parses it and reaches `SUNoUpdateError`, silent on a
background check — where a missing file is an error dialog.

**The feed is written from PUBLISHED releases, never from the
draft.** `release.yml` drafts, and a draft's asset URL is
unfetchable without auth, so an item written at tag time
advertises an update every installed copy fails to download for
as long as the highlights take to curate. `appcast-sync` reads
the releases API and skips anything still a draft;
`.github/workflows/changelog.yml` runs it on `release:
published`, alongside the notes it shares a corpus with.
`.claude/rules/site.md` owns the generated file itself.

**Three clauses decide whether a release enters the feed, and
`scripts/appcast-sync` names the one that failed:** it is
published; it carries exactly one distributable `.zip`, never a
`-unnotarized.zip` that Sparkle downloads in full and then
refuses; and that archive has a `.edsig` sidecar.

**Those clauses count `.zip` assets, and widening them is what
must not happen.** `archive_asset` filters to `.zip` before it
counts, so an artifact of any other type — the promoted disk
image first — never reaches the ambiguity refusal, and a release
carrying one is the ordinary shape rather than a condition to
relax. `AppcastParserTests` holds both halves: the refusal it
must keep, and the image-beside-the-archive case it must never
fire on. The feed is also not the only reader of a release's
asset list, so an artifact added to a release answers to every
one of them — `.github/workflows/homebrew.yml` selects the
cask's archive by exact name (`HomebrewCaskUpdateTests`), which
is what makes a third asset harmless there.

No version cutoff is written anywhere and none should be — the
releases
that predate the updater have no sidecar and fall out of the feed
as a consequence of the data rather than of a number someone has
to remember. `AppcastParserTests` pins each refusal.

**The signature is produced where the bytes are, and travels as a
sidecar** (`AppcastSigningWorkflowTests` and
`AppcastPublishWorkflowTests`, and `SparkleKeyDerivationTests`
for the key check below)**.** `release.yml` signs the archive it
has just built and attaches `<archive>.edsig` to the release;
the sync job reads it there.
That split is what lets the feed be written by a job that never
holds the private key, and it is why the sidecar is renamed and
dropped in step with the archive it signs — the two are paired by
name.

**Prove the key is THE key before signing with it.** Signing and
then verifying with the same key shows the secret is
self-consistent and nothing more — a valid but wrong key passes,
and the first person offered the update is the one who finds out.
`release.yml` derives the public half
(`scripts/sparkle-public-key.js`) and refuses to sign unless it
equals the `SUPublicEDKey` the packager ships.

**Sign with `--ed-key-file -`, never `-s`.** `sign_update` 2.9.6
refuses `-s` outright for a key in the current format, after
printing a deprecation warning that reads like a warning rather
than a failure; the key stanza reaches the tool on stdin
instead. Verify what was signed before shipping it — the tool's
`--verify` exits non-zero on a bad signature, and a signature no
installed copy accepts is an update that fails on every user's
machine and nowhere else.

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

**Attach every artifact the release builds (#968).**
`release.yml` asks `build-app.sh` for both — the archive the
cask installs and Sparkle downloads, and the disk image a
promoted download points at — and an artifact built and not
attached is invisible: the run is green, the notarization
succeeded, and the draft simply lacks a download nobody misses
until a link points at it. `ReleaseArtifactWorkflowTests`
reads the list off the build step's own argument array rather
than restating it, and holds each flag it finds to four things:
a step locates it, the draft step is handed that step's path,
the upload set carries it, and the superseded-asset cleanup
routes it. That last one is not a nicety — every artifact
carries the `-unnotarized` rename, so one attached and not
cleaned up leaves a draft offering both names — and which of the
two a person reaches for is not something to find out. **Read the
consuming side's rename once**, per artifact rather than per
copy: the workflow's `sibling_of` is that one reading, and the
per-artifact `case` block it replaced was already the second.

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

**`release.sh` must never push `main`; the stamp gets there
through a PR and the tag is cut on a second run.**
`ReleasePushSeamTests` holds the first half. `scripts/protect-main.sh`
applied #487's ruleset with `enforce_admins` TRUE — observed
2026-08-18 refusing a release push with `GH006: Protected branch
update failed` — so nothing pushes `main` directly and no one,
the owner included, can bypass that. `release.sh`
therefore runs twice on the same command: phase A stamps, gates,
commits onto `chore/stamp-<version>`, pushes that branch and
opens its PR; phase B, on a synced `main` after the merge, gates
again and pushes **only** the tag. It never attempts a push of
`main` at all.

Write the two phases as one script rather than two, and let it
pick the phase from whether the stamp changed anything — asked of
`git`, never by re-reading `KiwiDeskVersion.swift`, which
`bump-version.sh` is the one owner of. The reason this is a rule
and not a convenience: the stamps for 0.9.1, 0.9.5 and 0.9.6 each
reached `main` on a branch opened *by hand* after the script had
already failed at its push, three releases in a row rescuing the
same failure from memory. A release procedure that is only
correct when the operator remembers to deviate from it is the
thing being fixed here.

**Phase B skips its gate only on an exact tree match, and fails
closed.** A release otherwise runs the gate five times — phase A
locally, CI on the stamp PR, CI again on `main` post-merge, phase
B locally, `release.yml` on the tag — and phase B's is the one
that buys nothing, being the tree CI just verified. So phase A
records `HEAD^{tree}` and phase B compares against it.

Key the skip on the tree hash and nothing weaker. A version
match, a timestamp, or "phase B trusts CI" would each skip on a
tree nothing had verified; a squash merge of only the stamp
reproduces phase A's tree exactly, and any other commit landing
between changes the hash so the gate runs. Write no record on a
`--skip-verify` run — it attests to nothing — and treat a
missing, empty or unreadable record as "run the gate".
`ReleaseGateSkipTests` holds that shape and states in its own doc
comment what a text scan cannot see.

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

**The release body has a form, and a parser enforces it (#873).**
A curated `## Highlights` block sits on top, `--generate-notes`'
list underneath unedited. Under `## Highlights`: one or two
sentences of summary, then `###` sections whose titles the author
chooses, each carrying at least one entry. **Curate the draft,
then publish** — `release.yml` drafts, and
`.github/workflows/changelog.yml` fires on *publish* and syncs the
body onto the site's release-notes page AND into Sparkle's feed,
so publishing an uncurated body shows the raw generated list
until a correction lands — in the update window as well as on the
page, since both render the one curated block.
`scripts/release.sh` prints the skeleton after the tag push,
and `scripts/changelog-sync --body <file>` reads a DRAFT's body
from a file — the mode to use before publishing, since a
draft has no tag for `--release` to fetch. The same parser
refuses a body it cannot read rather than half-rendering it, and
`ChangelogParserTests` pins every refusal. `.claude/rules/site.md`
owns the generated file and the rest of that contract.

**Write the highlights for the installer, not for yourself.** A
release body is two tiers: a curated highlights block on top, and
beneath it the `--generate-notes` list the workflow already
creates, unedited, separated by an empty line. The highlights
name symptoms a reader would recognise rather than the mechanism
that produced them, carry no issue numbers (the generated list
below is the linked record), and stop at the few that are
genuinely news. The argument, the test to apply, and the worked
before/after that produced the rule are
`docs/design-decisions.md` ▸ *Release notes are written for the
person installing* — which also records why this one has no
guard.

**Nor is the ORDER a download channel opens in.**
`docs/design-decisions.md` ▸ *No distribution channel without an
update path* rules it — release page first, on a release cut to
be verified on a clean machine, and the site only afterwards —
and the person about to get it wrong is reading a release
procedure rather than a product decision, which is why it is
pointed at from here.

**Publishing is not this file's call.** The workflow drafts the
release rather than publishing it, and "No distribution channel
without an update path" in `docs/design-decisions.md` owns both
the reason and what a draft does and does not expose. Do not
change that step to publish without changing that entry first —
restating its argument here is how the two copies came to
disagree about a draft's reach on the day they were written.

**Advance Homebrew only after publication.**
`.github/workflows/homebrew.yml` owns the tap update: the
`release.published` event is the distribution boundary, never the
tag push or draft creation. It must verify the release's one ZIP
against GitHub's SHA-256 digest before changing the cask, and its
write credential stays scoped to `KiwiCanopy/homebrew-tap`. A
manual dispatch is a retry of that same published asset, not an
alternate way to build or publish one.

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
staged, and **refuses a commit made while HEAD is `main`** — the
exposure that actually bites is committing to `main` believing
HEAD is a feature branch, and the hook catches that before the
push does.

It predates server-side protection, which the free plan refused
for a private repo (`403 Upgrade to GitHub Pro or make this
repository public`) until the public flip let
`scripts/protect-main.sh` apply #487's ruleset. Both still earn
their keep: the ruleset is what red CI cannot get past, and the
hook is what tells you *before* you have written the commit.

Deliberately the commit, not the push: ff-merging a reviewed
branch legitimately writes to `main`. Override a genuinely
intended one with `KIWIDESK_ALLOW_MAIN_COMMIT=1`, which names the
rule you are skipping instead of `--no-verify` taking the lint
and locale checks with it.

## CI

`.github/workflows/ci.yml` builds, lints, and tests on pushes to
`main` and on PRs targeting it. Both jobs are gated on a `changes`
job, so a change confined to `.github/ci-ignore.txt`'s list leaves
them skipped. A red build blocks merging. The release build runs
as a separate, non-blocking job (#532) — when to run it locally
instead is decided by the `verify-gate` skill, which owns that
call.

**`ci.yml` filters by exclusion; `site.yml` filters by
inclusion.** Keep it that way. The site build's inputs are a
closed, small set, so naming them is safe. The app's are open, and
an include list there fails *open* — add a directory, forget to
map it, and its suites stop running while CI stays green.
Excluding is the failure this repo can afford: a missing entry
costs runner minutes, not correctness. Those minutes are the
reason the filter exists at all, macOS runners billing at a 10x
multiplier against the free allowance while the repo is private.

**Gate the expensive jobs, never the trigger.** A workflow filtered
out by `paths-ignore` never reports a check run at all — not
skipped-as-success, absent — so a required status check waits
forever on it. A job skipped by `if:` satisfies one. Both shapes
save the same macOS minutes; only the second survives
`scripts/protect-main.sh` (#487). `ci.yml` therefore always
triggers, and a cheap `ubuntu-latest` `changes` job reads
`.github/ci-ignore.txt` and gates the two macOS jobs on its
output.

**Add an entry to `.github/ci-ignore.txt` only when no test, no
build step and no lint step reads the path** — and audit all three,
not just the first. `CiPathFilterTests` holds the line, checks the
workflow still consults the list and still gates on it, and states
in its own doc comment what it cannot see. Read that before adding
an entry; a deep multi-component path earns much weaker cover than
a whole top-level directory.

**A workflow that changes the tree opens a PR; it never writes to
`main`.** `.github/workflows/app-font.yml` watches the vendored
SketchyBar App Font weekly and is the shape to copy for any later
**watcher** — something that polls an upstream nobody here
controls. The Sparkle appcast is deliberately NOT one: it is
generated from this repo's own published releases, on the
`release: published` event, so it lives beside the notes it
shares a corpus with in `changelog.yml` rather than in a poller
of its own. What it does inherit is this rule's first clause —
run the gate before the PR exists, because a PR opened with
`GITHUB_TOKEN` fires no workflows, so `changelog.yml` runs the
site build AND `check-site-tokens.py` itself. Three obligations, all
enforced by `AppFontWorkflowTests`: it **calls the developer
script** rather than re-implementing the vendoring inline, because
only the hand-run path is ever exercised outside the cron; it
**gates the macOS job on a cheap `ubuntu-latest` check**, the same
trade `ci.yml` makes; and it **runs the gate before the PR
exists** — a PR opened with `GITHUB_TOKEN` does not fire
`pull_request`, so `ci.yml` reports nothing on it and the workflow
run log is the only proof the drop was ever built.

**A workflow-opened PR gets its CI started for it, and one it
expects to merge itself gets armed too.** Running the gate before
the PR exists proves the change; it does not get the PR merged.
Branch protection requires `ci.yml`'s two macOS contexts, and a
PR opened with `GITHUB_TOKEN` fires no `pull_request`, so neither
ever reports and the PR sits BLOCKED — the release path hit that
at v1.1.1, and every release before #1154 needed a human between
publishing and the feed going live. So the workflow starts
`ci.yml` itself, through `workflow_dispatch`, which is the one
event a `GITHUB_TOKEN` may still create (observed 2026-08-31
against this repo), and arms auto-merge beside it.

**Both halves are owed to a PR nobody is watching land, and
that is the scope.** The release path is unwatched by
construction — publish, and the feed waits on the sync PR — so
it owes both. `app-font.yml`'s PR is the other shape: a human
reads it before it lands, because an upstream drop can restyle
a glyph, so auto-merge would be wrong there and its manual CI
start is a cost its reviewer already pays. That is a scope line,
not an argument that it is fine: the two halves are separable,
and a workflow-opened PR that acquires an unwatched landing owes
the dispatch on the day it does.

**The dispatch is filtered, and that buys the PR leg only.** It
passes `filter_paths`, asking that run to apply
`.github/ci-ignore.txt` the way the `pull_request` it stands in
for would — so a `site/**`-only sync reports both contexts as
skipped in under a minute instead of paying a full macOS build
before the queue can even take it. The **queue leg still builds
unfiltered**: `merge_group` has no base to diff against and
resolves to "run everything", which is the fail-closed default
and stays that way. The button's default stays OFF for a
different reason again — it is the manual override for a WRONG
entry on that list (#661), and an override that re-read the list
would be no override.

`ReleaseSyncTriggerTests` holds both halves, scoped through
`workflowSource`/`workflowStep` rather than a reader of its own,
and reads every input name off the dispatching side to require
it of the accepting one. That parity is worth having even though
a one-sided rename is not silent: the dispatch API refuses an
undeclared input outright (`422 Unexpected inputs provided`,
observed 2026-08-31), so the failure lands on the release run —
after publishing, with the feed waiting — and the guard moves it
to PR time. It states in its own doc comment what it cannot see:
the merge queue's willingness to take an entry a bot armed is
answered only by a real release.

**A path a rule file pins is a path the suite reads.**
`InstructionPinTests` resolves every non-glob `paths:` entry in
`.claude/rules/*.md`, so ignoring one makes its rename a
CI-skipping change that reds `main` afterwards. `docs/**` looked
like the safest entry on the list for exactly the wrong reason —
no test opens a docs page, but `localization.md` pins two — and it
reached review before the guard grew a check for it.
