// Drives src/lib/changelog-view.ts over typed and legacy fixtures
// (#1542). Run by site.yml and changelog.yml; `node
// site/test-changelog.mjs` locally after `npm ci`.
//
// It exists because the corpus holds no typed release before
// 2.0.0, so check-site-tokens.py ▸ check_typed_changelog passes
// for having looked at nothing until then — and the sync PR it
// first bites on also carries the update feed 1.x clients take
// to 2.0.0. This is the view's live subject; that check is the
// built page's.

import { releaseInline, sectionView } from "./src/lib/changelog-view.ts";
import { pngSize, releaseImage } from "./src/lib/release-image.ts";

const failures = [];
let ran = 0;

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

check("a typed section counts its items", () => {
  const view = sectionView({
    title: "Fixed",
    items: ["**A**.", "B."],
    type: "fixed",
  });
  assert(view.count === 2, `count ${view.count}`);
  assert(!view.folded, "a fixed section must not fold");
});

check("the scripting section folds, by type", () => {
  const view = sectionView({
    title: "Lua & CLI",
    items: ["`x`"],
    type: "scripting",
  });
  assert(view.folded, "the scripting section must fold");
  assert(view.count === 1, `count ${view.count}`);
});

check("the fold follows the type, never the title", () => {
  const renamed = sectionView({
    title: "Scripting",
    items: ["x"],
    type: "scripting",
  });
  const lookalike = sectionView({ title: "Lua & CLI", items: ["x"] });
  assert(renamed.folded, "a renamed scripting title must still fold");
  assert(!lookalike.folded, "a legacy title must not fold");
});

check("a release before 2.0.0 carries no count", () => {
  const view = sectionView({ title: "Windows behave", items: ["x"] });
  assert(view.count === null, `count ${view.count}`);
});

check("items render their inline markdown", () => {
  const view = sectionView({
    title: "New",
    items: ["**Bold** and `code`."],
    type: "new",
  });
  const html = view.items[0];
  assert(html.includes("<strong>Bold</strong>"), html);
  assert(html.includes("<code>code</code>"), html);
});

check("raw HTML is shown as text, as in the feed", () => {
  const html = releaseInline("Press <kbd>x</kbd> **now**.");
  assert(html.includes("&lt;kbd&gt;x&lt;/kbd&gt;"), html);
  assert(!html.includes("<kbd>"), html);
  assert(html.includes("<strong>now</strong>"), html);
});

check("a release image is sized from its PNG header", () => {
  const ihdr = Uint8Array.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
    0, 0, 0x04, 0x38, 0, 0, 0x02, 0x1c,
  ]);
  const size = pngSize(ihdr);
  assert(size.width === 1080 && size.height === 540, JSON.stringify(size));
});

check("a release image that is no PNG fails the build", () => {
  let threw = false;
  try {
    pngSize(new TextEncoder().encode("GIF89a, not a png at all...."));
  } catch {
    threw = true;
  }
  assert(threw, "a non-PNG was sized");
});

check("an image the tree lacks fails the build", () => {
  let threw = false;
  try {
    releaseImage("/releases/0.0.0-absent.png");
  } catch (error) {
    threw = error.message.includes("/releases/0.0.0-absent.png");
  }
  assert(threw, "a missing image did not name its route");
});

if (failures.length) {
  console.error(`test-changelog: ${failures.length} of ${ran} failed`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log(`test-changelog: ${ran} check(s) passed`);
