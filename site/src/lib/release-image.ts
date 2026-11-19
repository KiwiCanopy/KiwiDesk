// A release's one image (design-decisions ▸ A release carries at
// most one image), sized off its PNG header.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export interface ReleaseImage {
  src: string;
  width: number;
  height: number;
}

const PNG_SIGNATURE = "89504e470d0a1a0a";

// Width and height from a PNG's IHDR chunk. Throws on anything
// else: a route the data names and the tree lacks fails the build
// rather than shipping a broken image.
export function pngSize(bytes: Uint8Array): { width: number; height: number } {
  const head = Buffer.from(bytes.subarray(0, 24));
  if (
    head.length < 24 ||
    head.subarray(0, 8).toString("hex") !== PNG_SIGNATURE ||
    head.subarray(12, 16).toString("latin1") !== "IHDR"
  ) {
    throw new Error("not a PNG");
  }
  return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
}

// `publicDir` is the test seam; the build runs in site/.
export function releaseImage(
  route: string,
  publicDir: string = resolve(process.cwd(), "public"),
): ReleaseImage {
  const file = resolve(publicDir, route.replace(/^\/+/, ""));
  try {
    return { src: route, ...pngSize(readFileSync(file)) };
  } catch (error) {
    throw new Error(
      `changelog.json names ${route}, and ${file} is not a readable ` +
        `PNG (${(error as Error).message})`,
    );
  }
}
