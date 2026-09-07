// Drives remark-unreleased.mjs over fixtures and asserts the HTML
// it produces (#1232). Run by site.yml; `node site/test-unreleased.mjs`
// locally after `npm ci`.
//
// It exists because the corpus is usually EMPTY of markers —
// `scripts/unreleased-strip` removes them all at every release —
// so a guard over the built pages alone passes for having found
// nothing, which is the shape .claude/rules/rule-authoring.md ▸
// "Prove a new guard reds" names as its sharpest instance. This
// is the plugin's live subject; check-site-tokens.py ▸
// check_unreleased_markers is the artifact's.
//
// The pipeline below is assembled by hand rather than borrowed
// from Astro on purpose: `remark-directive` reaches the real
// build through Starlight's asides and nothing we declare, so a
// runner that inherited Astro's processor could not tell us that
// our own plugin works when Starlight's arrangement changes.

import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkDirective from "remark-directive";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import {
  remarkUnreleased,
  DIRECTIVE,
  CLASS,
  TITLE_CLASS,
  LABEL,
} from "./remark-unreleased.mjs";

const render = (markdown) =>
  unified()
    .use(remarkParse)
    .use(remarkDirective)
    .use(remarkUnreleased)
    .use(remarkRehype)
    .use(rehypeStringify)
    .processSync(markdown)
    .toString();

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

function throws(markdown, needle) {
  let raised = null;
  try {
    render(markdown);
  } catch (error) {
    raised = error;
  }
  assert(raised !== null, "expected a throw, got clean output");
  assert(
    raised.message.includes(needle),
    `expected the error to mention "${needle}", got: ` +
      raised.message
  );
}

const marked = `:::${DIRECTIVE}\nEach Desktop owns its Spaces.\n:::\n`;

check("a marked block is badged", () => {
  const html = render(marked);
  assert(
    html.includes(`class="${CLASS}"`),
    `no .${CLASS} element in: ${html}`
  );
  assert(html.includes("<aside"), `not an <aside>: ${html}`);
  assert(
    html.includes(`aria-label="${LABEL}"`),
    `the aside carries no accessible name: ${html}`
  );
  // ONE contiguous needle, because the two halves spelled
  // separately were each satisfied by something else: `LABEL`
  // alone is implied by the aria-label clause above, and a bare
  // `aria-hidden` matches the attribute anywhere in the document.
  // Together they passed on a badge rendering with NO visible
  // text at all — which is the entire user-facing point of the
  // feature (guard-prover, #1232).
  //
  // What it costs: this now pins rehype's attribute ORDER and the
  // element spelling, so an upstream serializer change, or
  // wrapping the title in anything, mis-fires here with a
  // diagnosis about the title being missing. It also leaves
  // `aria-hidden` asserted nowhere on its own — if this needle is
  // ever loosened, that clause comes back separately.
  assert(
    html.includes(
      `<p class="${TITLE_CLASS}" aria-hidden="true">${LABEL}</p>`
    ),
    `the visible title is not drawn as its own element: ${html}`
  );
});

check("the block's own prose survives", () => {
  assert(
    render(marked).includes("Each Desktop owns its Spaces."),
    "the plugin dropped the content it was wrapping"
  );
});

check("an unmarked page is untouched", () => {
  const html = render("Ordinary prose.\n");
  assert(
    !html.includes(CLASS),
    `an unmarked page picked up a badge: ${html}`
  );
});

// The three refusals. Each is a spelling an author would
// plausibly reach for, and each renders as a bare <div> with no
// trace of the marker if the plugin lets it through — the exact
// silent failure the badge exists to prevent.
check("a version attribute is refused", () => {
  throws(`:::${DIRECTIVE}{version="1.3.0"}\nx\n:::\n`, "version");
});

check("a leaf directive is refused", () => {
  throws(`::${DIRECTIVE}\n`, "container block");
});

check("a text directive is refused", () => {
  throws(`Some :${DIRECTIVE}[x] prose.\n`, "container block");
});

// Not a refusal: this is what the built pages would ship if
// `remark-directive` ever stopped reaching the pipeline, and it
// is what check_unreleased_markers' first clause watches for.
check("an unparsed marker is visible, not swallowed", () => {
  const html = unified()
    .use(remarkParse)
    .use(remarkUnreleased)
    .use(remarkRehype)
    .use(rehypeStringify)
    .processSync(marked)
    .toString();
  assert(
    html.includes(`:::${DIRECTIVE}`),
    "without remark-directive the marker vanished rather than " +
      `shipping as prose, so the artifact guard cannot see it: ${html}`
  );
});

if (failures.length) {
  console.error(
    `test-unreleased: ${failures.length} failure(s)\n  - ` +
      failures.join("\n  - ")
  );
  process.exit(1);
}
if (!ran) {
  console.error("test-unreleased: no check ran at all");
  process.exit(1);
}
// The count is printed rather than pinned: pinning it would red
// on every legitimate addition, while printing it puts a deleted
// check in front of whoever reads the diff or the CI log.
console.log(`test-unreleased: OK (${ran} checks)`);
