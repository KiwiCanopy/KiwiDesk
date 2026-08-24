import changelog from "../data/changelog.json";

interface ReleaseEntry {
  version?: string;
  download?: string;
  prerelease?: boolean;
}

/**
 * The newest published release that carries a promoted download,
 * or `undefined` when none does.
 *
 * Bound ONCE, and both exports below are derived from it. Two
 * hand-written `.find()` calls would agree only for as long as
 * their predicates stayed identical text — and the moment either
 * grew a clause the other did not (a `prerelease` filter, say),
 * the page would offer one release's bytes under another
 * release's version, with nothing comparing them.
 *
 * The entries are newest-first, which `changelog-sync`'s own
 * `_sort_key` guarantees.
 */
const promoted = (changelog.releases as ReleaseEntry[]).find(
  (release) =>
    typeof release.download === "string" && release.download,
);

/**
 * The promoted direct download (#904), or `null` when no
 * published release carries one.
 *
 * The URL is a release's OWN `.dmg` asset URL, recorded by
 * `scripts/changelog-sync` off the releases API — never composed
 * here from a version string. The argument for that, and for
 * omitting a download affordance outright rather than dimming
 * it, is `.claude/rules/site.md` ▸ *A promoted download link is
 * read off the release's own asset list*.
 *
 * It lives here rather than in each page because the SELECTION
 * rule is a decision, not a formatting detail: `Landing.astro`
 * and `Guide.astro` must offer the same build.
 */
export const downloadHref: string | null = promoted?.download ?? null;

/** The version those bytes are of, or `null`. */
export const downloadVersion: string | null =
  promoted?.version ?? null;

/**
 * Whether the promoted build is flagged a prerelease, straight
 * from the release GitHub published.
 *
 * The pill that used to read "Public beta — available now" was a
 * hand-maintained claim: true when written, and wrong from the
 * moment 1.0 shipped until someone remembered to edit it. Reading
 * the flag means the badge cannot fall out of step with what the
 * download actually is — it says beta while a beta is what you
 * would get, and stops on its own when that stops being true.
 */
export const downloadIsPrerelease: boolean =
  promoted?.prerelease === true;
