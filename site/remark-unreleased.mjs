import { visit } from "unist-util-visit";

// Badges a docs block that describes behavior `main` has but no
// release does (#1232). `.claude/rules/site.md` ▸ "Unreleased docs
// mark themselves" owns the argument, including why the marker
// names no version and what retires it.
//
//   :::unreleased
//   Each Desktop now owns its own Spaces…
//   :::
//
// Reads nothing and decides nothing: `scripts/unreleased-strip`
// removes every marker at release time, so a marker still in the
// corpus IS unreleased.

export const DIRECTIVE = "unreleased";
export const CLASS = "kd-unreleased";
export const LABEL = "Unreleased — not in the current release";
export const TITLE_CLASS = "kd-unreleased__title";

export function remarkUnreleased() {
  return (tree, file) => {
    visit(tree, (node) => {
      if (!/^(container|leaf|text)Directive$/.test(node.type)) {
        return;
      }
      if (node.name !== DIRECTIVE) return;
      const where = file.path ?? "(unknown file)";
      // Loud, because the quiet failure is the one this marker
      // exists to prevent: an unhandled directive renders as a
      // bare <div> and the reader is told nothing.
      if (node.type !== "containerDirective") {
        throw new Error(
          `[remark-unreleased] ${where}: ":${DIRECTIVE}" must be ` +
            "a ::: container block."
        );
      }
      const attributes = Object.keys(node.attributes ?? {});
      if (attributes.length) {
        throw new Error(
          `[remark-unreleased] ${where}: ":::${DIRECTIVE}" takes ` +
            `no attributes (got ${attributes.join(", ")}). A ` +
            "version here would look load-bearing and be ignored."
        );
      }

      // Starlight's own aside shape: the aside carries the
      // accessible name and the visible title is hidden from
      // assistive tech, so the label is announced once.
      node.data = {
        ...(node.data ?? {}),
        hName: "aside",
        hProperties: { class: CLASS, "aria-label": LABEL },
      };
      node.children.unshift({
        type: "paragraph",
        data: {
          hName: "p",
          hProperties: { class: TITLE_CLASS, "aria-hidden": "true" },
        },
        children: [{ type: "text", value: LABEL }],
      });
    });
  };
}
