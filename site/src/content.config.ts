import { defineCollection } from "astro:content";
import { docsLoader } from "@astrojs/starlight/loaders";
import { docsSchema } from "@astrojs/starlight/schema";
import type { Loader, LoaderContext } from "astro/loaders";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

// Astro 5's glob loader logs a spurious `Duplicate id` warning
// whenever a build re-syncs a file whose contents changed since
// the persisted data store was written: the "duplicate" it finds
// is the entry's own stale store record, not a second file (the
// docs/ symlink is innocent — a cold build is warning-free).
// Astro 6 fixed this upstream by warning only when the stored
// entry points at a *different* file that still exists. Until
// the site is on Astro 6, replicate that check here and drop
// the same-file false positive. Real duplicates (two files that
// produce one id) still warn. Delete this wrapper when
// upgrading Astro.
const duplicateWarning = new RegExp(
  '^Duplicate id "(.+)" found in (.+)\\. ' +
    "Later items with the same id will overwrite earlier ones\\.$",
);

function withoutStaleResyncWarnings(loader: Loader): Loader {
  return {
    ...loader,
    load(context: LoaderContext) {
      const { logger, store, config } = context;
      const root = fileURLToPath(config.root);
      const quiet = Object.create(logger) as typeof logger;
      quiet.warn = (message: string) => {
        const match = duplicateWarning.exec(message);
        // At warn time the store still holds the previous entry
        // for this id; when it lives at the very file being
        // warned about, this is a stale re-sync of that file,
        // not a duplicate. Anything else passes through.
        const owner = match && store.get(match[1])?.filePath;
        if (owner && resolve(root, owner) === match[2]) return;
        logger.warn(message);
      };
      return loader.load({ ...context, logger: quiet });
    },
  };
}

export const collections = {
  docs: defineCollection({
    loader: withoutStaleResyncWarnings(docsLoader()),
    schema: docsSchema(),
  }),
};
