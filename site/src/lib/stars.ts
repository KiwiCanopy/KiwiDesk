/**
 * The repo's GitHub star count, read ONCE per build.
 *
 * Build time, not in the browser: the site's CSP (`public/_headers`,
 * `connect-src 'self'`) and its privacy policy both promise no
 * third-party request from a visitor's page (#1659). The call is
 * unauthenticated — Cloudflare Pages passes no secret to a build
 * (`.claude/rules/site.md`) — so a shared build IP can hit the
 * 60-an-hour limit.
 *
 * Any failure falls back to `FALLBACK`, a count the repo has
 * already reached, and says so in the build log so a frozen number
 * is visible there. Raise it now and then.
 */
const FALLBACK = 88;
const API = "https://api.github.com/repos/KiwiCanopy/KiwiDesk";

const fallback = (why: string): number => {
  console.warn(`[stars] using fallback ${FALLBACK}: ${why}`);
  return FALLBACK;
};

async function read(): Promise<number> {
  try {
    const res = await fetch(API, {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return fallback(`HTTP ${res.status}`);
    const n = (await res.json())?.stargazers_count;
    return Number.isInteger(n) && n >= 0
      ? n
      : fallback("no stargazers_count in the response");
  } catch (error) {
    return fallback(String(error));
  }
}

export const githubStars: number = await read();

/** The count as `lang` writes it, compact past a thousand. */
export const formatStars = (lang: string): string =>
  new Intl.NumberFormat(lang, {
    notation: githubStars >= 1000 ? "compact" : "standard",
    maximumFractionDigits: 1,
  }).format(githubStars);
