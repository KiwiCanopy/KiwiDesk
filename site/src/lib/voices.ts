import { createImageUrlBuilder } from "@sanity/image-url";

/**
 * Users' words on the landing page's voices section, read ONCE per
 * build from Sanity (#2369) so their names and photos stay out of
 * this public repo: a withdrawn consent is a Sanity delete, not a
 * commit, live at the next build (`.claude/rules/site.md` ▸ *Build-
 * time reads*). The documents are `kiwideskVoice` in the KiwiCanopy
 * Studio (KiwiCanopy/KiwiCanopy-Sanity-Studio).
 *
 * Build time, not in the browser, like `stars.ts`: the CSP
 * (`public/_headers`) and the privacy policy promise no
 * third-party request from a visitor's page, so photos go through
 * Astro's image pipeline and are served from the site itself
 * (`image.remotePatterns`, `check-site-tokens.py` ▸
 * `check_no_sanity_in_dist`). The read is unauthenticated against
 * the public dataset, published documents only; Pages passes no
 * secret to a build (`.claude/rules/site.md`).
 *
 * A failed read renders NO section and says so in the build log —
 * never a committed snapshot, which would put the data back here —
 * and a photo the CDN does not serve falls back to the monogram, so
 * a Sanity hiccup never fails the deploy that would carry a
 * withdrawal. The site gate reds instead when the landing draws no
 * voice (`check-site-tokens.py` ▸ `check_voices_rendered`).
 */
export const SANITY_PROJECT = "k8d0znuy";
const DATASET = "production";
const API_VERSION = "2025-02-19";

const QUERY = `*[_type == "kiwideskVoice"]
  | order(order asc, _createdAt asc)
  { name, role, quote, link, source, photo }`;

/**
 * One voice. `quote` stays English on every locale — a translated
 * testimonial puts words in someone's mouth — so the page marks it
 * `lang="en"`. `avatar` is a cdn.sanity.io URL the build downloads,
 * or `null` (a monogram is drawn). `link` points at the person, not
 * necessarily where they said it.
 */
export interface Voice {
  name: string;
  /** What they do; `null` when there is nothing to say. */
  role: string | null;
  quote: string;
  avatar: string | null;
  link: string;
  source: string;
}

/** Edge length, in pixels, of the photo the build downloads: 2x
 * the 88 px the page draws (`densities` in `Landing.astro`). */
const AVATAR_PX = 176;

const images = createImageUrlBuilder({
  projectId: SANITY_PROJECT,
  dataset: DATASET,
});

const text = (v: unknown): string | null =>
  typeof v === "string" && v.trim() !== "" ? v.trim() : null;

/** A row as the page draws it, or `null` when it is malformed. */
function toVoice(row: any): Voice | null {
  const name = text(row?.name);
  const quote = text(row?.quote);
  const link = text(row?.link);
  const source = text(row?.source);
  if (!name || !quote || !link?.startsWith("https://") || !source) {
    return null;
  }
  let avatar: string | null = null;
  if (row.photo?.asset?._ref) {
    try {
      avatar = images
        .image(row.photo)
        .width(AVATAR_PX)
        .height(AVATAR_PX)
        .fit("crop")
        .url();
    } catch {
      avatar = null;
    }
  }
  return { name, role: text(row.role), quote, avatar, link, source };
}

/** `voice` with its photo dropped unless the CDN serves it now. */
async function withReachablePhoto(voice: Voice): Promise<Voice> {
  if (!voice.avatar) return voice;
  try {
    const res = await fetch(voice.avatar, {
      method: "HEAD",
      signal: AbortSignal.timeout(5000),
    });
    if (res.ok) return voice;
    console.warn(`[voices] photo of ${voice.name}: HTTP ${res.status}`);
  } catch (error) {
    console.warn(`[voices] photo of ${voice.name}: ${error}`);
  }
  return { ...voice, avatar: null };
}

const none = (why: string): Voice[] => {
  console.warn(`[voices] rendering no voices section: ${why}`);
  return [];
};

async function read(): Promise<Voice[]> {
  const url = new URL(
    `https://${SANITY_PROJECT}.api.sanity.io/v${API_VERSION}` +
      `/data/query/${DATASET}`
  );
  url.searchParams.set("query", QUERY);
  url.searchParams.set("perspective", "published");
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return none(`HTTP ${res.status}`);
    const rows = (await res.json())?.result;
    if (!Array.isArray(rows)) return none("no result in the response");
    if (rows.length === 0) return none("no kiwideskVoice documents");
    const list = rows.map(toVoice);
    const dropped = list.filter((v) => v === null).length;
    if (dropped > 0) console.warn(`[voices] dropped ${dropped} malformed`);
    const valid = list.filter((v): v is Voice => v !== null);
    return await Promise.all(valid.map(withReachablePhoto));
  } catch (error) {
    return none(String(error));
  }
}

export const voices: Voice[] = await read();

/** Initials for a voice without a picture: "Jeff Moore" → "JM". */
export const monogram = (name: string): string =>
  name
    .split(/\s+/)
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
