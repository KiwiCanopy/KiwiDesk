/**
 * Discover, the looks gallery's default order (#1740 ▸ Sorting): a
 * fair daily rotation computed at build time from the UTC date.
 * Pure — no fetch, no clock read unless `now` is defaulted — so
 * `site/test-looks-order.mjs` drives it on every site build.
 *
 * Cycles are counted from `EPOCH` and walked forward day by day.
 * A cycle's deck is every look that existed and was not new at its
 * first day, shuffled with the cycle number as seed. Each day the
 * top block shows the deck from the current offset on, and the
 * offset then moves by that day's free places, so the cycle lasts
 * ceil(deck / free) days and every deck look reaches the top block
 * once in it. A look that stops being new mid-cycle joins the END
 * of the current deck. New looks (added fewer than 14 days ago)
 * lead the top block, at most two, and are never in the deck, so
 * they take no one's turn. Likes and downloads never touch it.
 */

export interface Dated {
  id: string;
  /** `YYYY-MM-DD`, UTC. */
  added: string;
}

const DAY_MS = 86_400_000;
/** Day 0 of cycle 0: 2026-10-28 UTC. */
export const EPOCH_DAY = Math.floor(Date.UTC(2026, 9, 28) / DAY_MS);
/** Places in the top block kept for new looks. */
export const NEW_PLACES = 2;
/** A look is new while fewer than this many days old. */
export const NEW_WINDOW_DAYS = 14;

export const dayNumber = (iso: string): number =>
  Math.floor(Date.parse(`${iso}T00:00:00Z`) / DAY_MS);

/** Top block: 6 looks, 12 from 150. */
export const topBlock = (n: number): number => (n >= 150 ? 12 : 6);

/** Seeded PRNG (mulberry32). */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** `items` sorted by id, then shuffled by `seed`. */
function shuffled<T extends Dated>(items: T[], seed: number): T[] {
  const out = [...items].sort((a, b) => a.id.localeCompare(b.id));
  const random = mulberry32(seed);
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

export interface DiscoverDay<T extends Dated> {
  order: T[];
  /** How many of `order`'s first entries form the top block. */
  top: number;
  /** New looks leading `order`. */
  fresh: number;
  cycle: number;
}

/** Looks new on `day` (added that day or fewer than 14 days
 * before), newest first, same-day ties in a day-seeded order (never
 * by id). */
function freshOn<T extends Dated>(list: T[], day: number): T[] {
  const isNew = (l: T) => {
    const age = day - dayNumber(l.added);
    return age >= 0 && age < NEW_WINDOW_DAYS;
  };
  return shuffled(list.filter(isNew), day ^ 0x5bd1e995).sort(
    (a, b) => b.added.localeCompare(a.added),
  );
}

/** Discover on one UTC day (a day number). Replays from the epoch
 * with today's list: an added look never disturbs a cycle, but a
 * removed one drops out of past decks too, so a removal may reshuffle
 * the current cycle once (accepted, #1740). */
export function discoverDay<T extends Dated>(
  list: T[],
  today: number,
): DiscoverDay<T> {
  const added = new Map(list.map((l) => [l.id, dayNumber(l.added)]));
  let cycle = 0;
  let deck: T[] | null = null;
  let offset = 0;
  const last = Math.max(today, EPOCH_DAY);
  for (let day = EPOCH_DAY; ; day++) {
    const exist = list.filter((l) => added.get(l.id)! <= day);
    const old = (l: T) => day - added.get(l.id)! >= NEW_WINDOW_DAYS;
    if (deck === null) {
      deck = shuffled(exist.filter(old), cycle);
      offset = 0;
    } else {
      const inDeck = new Set(deck.map((l) => l.id));
      deck.push(...shuffled(
        exist.filter((l) => old(l) && !inDeck.has(l.id)), day,
      ));
    }
    const fresh = freshOn(list, day).slice(0, NEW_PLACES);
    const top = topBlock(exist.length);
    const free = Math.max(1, top - fresh.length);
    if (day === last) {
      const rotated = [...deck.slice(offset), ...deck.slice(0, offset)];
      const lead = new Set([...fresh, ...deck].map((l) => l.id));
      const rest = freshOn(list, day).filter((l) => !lead.has(l.id));
      const tail = list
        .filter((l) => !lead.has(l.id) && !rest.includes(l))
        .sort((a, b) => a.id.localeCompare(b.id));
      return {
        order: [...fresh, ...rotated, ...rest, ...tail],
        top: Math.min(top, list.length),
        fresh: fresh.length,
        cycle,
      };
    }
    offset += free;
    if (offset >= deck.length) {
      cycle += 1;
      deck = null;
    }
  }
}

export const discoverOrder = <T extends Dated>(
  list: T[],
  now = new Date(),
): T[] => discoverDay(list, Math.floor(now.getTime() / DAY_MS)).order;
