// Drives src/lib/looks-order.ts, the looks gallery's Discover
// rotation (#1740 ▸ Sorting), over synthetic galleries. Run by
// site.yml; `node site/test-looks-order.mjs` locally.

import {
  discoverDay,
  discoverOrder,
  EPOCH_DAY,
  NEW_WINDOW_DAYS,
} from "./src/lib/looks-order.ts";

const failures = [];
let ran = 0;
const DAY_MS = 86_400_000;
const iso = (day) => new Date(day * DAY_MS).toISOString().slice(0, 10);

function check(name, run) {
  ran += 1;
  try {
    run();
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** `n` looks, all added `age` days before the epoch. */
const gallery = (n, age = 60, prefix = "look") =>
  Array.from({ length: n }, (_, i) => ({
    id: `${prefix}-${String(i).padStart(3, "0")}`,
    added: iso(EPOCH_DAY - age),
  }));

const topIds = (state) =>
  state.order.slice(state.fresh, state.top).map((l) => l.id);

/** The days of the first complete cycle starting at or after `from`,
 * and every id the top block's rotating places showed in it. */
function fullCycle(list, from) {
  let day = from;
  const first = discoverDay(list, day).cycle;
  while (discoverDay(list, day).cycle === first) day += 1;
  const cycle = discoverDay(list, day).cycle;
  const seen = new Set();
  const days = [];
  for (; discoverDay(list, day).cycle === cycle; day += 1) {
    days.push(day);
    for (const id of topIds(discoverDay(list, day))) seen.add(id);
  }
  return { cycle, days, seen, next: day };
}

for (const n of [5, 6, 40, 151, 400]) {
  check(`every look reaches the top block within one cycle (${n})`, () => {
    const list = gallery(n);
    for (const from of [EPOCH_DAY, EPOCH_DAY + 37]) {
      const { seen, days } = fullCycle(list, from);
      const missed = list.filter((l) => !seen.has(l.id));
      assert(missed.length === 0,
        `${missed.length} never shown, e.g. ${missed[0]?.id}`);
      const top = n >= 150 ? 12 : 6;
      const expected = Math.ceil(n / top);
      assert(days.length === expected,
        `cycle ran ${days.length} days, not ${expected}`);
    }
  });
}

check("the same UTC date gives the same order", () => {
  const list = gallery(40);
  const day = EPOCH_DAY + 23;
  const morning = discoverOrder(list, new Date(day * DAY_MS + 60_000));
  const night = discoverOrder([...list].reverse(),
    new Date(day * DAY_MS + DAY_MS - 60_000));
  assert(morning.map((l) => l.id).join() === night.map((l) => l.id).join(),
    "order moved within one day or with the input order");
  const next = discoverOrder(list, new Date((day + 1) * DAY_MS));
  assert(morning[0].id !== next[0].id, "the order did not move next day");
});

check("every look appears exactly once in the order", () => {
  const list = [...gallery(40), ...gallery(3, 2, "new")];
  const { order } = discoverDay(list, EPOCH_DAY + 9);
  const ids = order.map((l) => l.id);
  assert(ids.length === list.length && new Set(ids).size === list.length,
    `${ids.length} entries, ${new Set(ids).size} distinct`);
});

check("a look added mid-cycle loses nobody's turn", () => {
  const list = gallery(40);
  const { days } = fullCycle(list, EPOCH_DAY);
  const mid = days[2];
  const arrival = { id: "arrival", added: iso(mid) };
  const withArrival = [...list, arrival];
  const seen = new Set();
  let day = days[0];
  const cycle = discoverDay(withArrival, day).cycle;
  for (; discoverDay(withArrival, day).cycle === cycle; day += 1) {
    const state = discoverDay(withArrival, day);
    for (const id of topIds(state)) seen.add(id);
    if (day >= mid && day - mid < NEW_WINDOW_DAYS) {
      assert(state.order[0].id === "arrival",
        `day ${day - mid} of the arrival does not lead`);
      assert(!topIds(state).includes("arrival"),
        "the new look took a rotating place");
    }
  }
  const missed = list.filter((l) => !seen.has(l.id));
  assert(missed.length === 0, `${missed.length} lost their turn`);
});

check("a look that stops being new mid-cycle gets its turn", () => {
  const list = gallery(400);
  const { days } = fullCycle(list, EPOCH_DAY);
  const joins = days[3];
  const late = { id: "late", added: iso(joins - NEW_WINDOW_DAYS) };
  const withLate = [...list, late];
  assert(discoverDay(withLate, joins - 1).order[0].id === "late",
    "not new the day before it joins");
  let shown = false;
  const cycle = discoverDay(withLate, joins).cycle;
  for (let day = joins; discoverDay(withLate, day).cycle === cycle; day++) {
    if (topIds(discoverDay(withLate, day)).includes("late")) shown = true;
  }
  assert(shown, "joined the deck but never reached the top block");
});

check("new means fewer than 14 days old, at most two lead", () => {
  const day = EPOCH_DAY + 30;
  const list = [
    ...gallery(20),
    { id: "edge", added: iso(day - NEW_WINDOW_DAYS) },
    { id: "a", added: iso(day - 1) },
    { id: "b", added: iso(day - 1) },
    { id: "c", added: iso(day - 1) },
  ];
  const state = discoverDay(list, day);
  assert(state.fresh === 2, `${state.fresh} new looks lead`);
  const lead = state.order.slice(0, 2).map((l) => l.id);
  assert(lead.every((id) => ["a", "b", "c"].includes(id)),
    `led by ${lead}`);
  assert(state.order.slice(0, state.top).length === 6, "top block not 6");
  const leaders = new Set();
  for (let d = day - 1; d > day - 8; d--) {
    const shifted = list.map((l) =>
      ["a", "b", "c"].includes(l.id) ? { ...l, added: iso(d - 1) } : l);
    leaders.add(discoverDay(shifted, d).order[0].id);
  }
  assert(leaders.size > 1, "same-day ties always break the same way");
});

if (failures.length > 0) {
  console.error(`looks order: ${failures.length} of ${ran} failed`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`looks order: ${ran} checks passed`);
