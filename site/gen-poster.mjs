// Generates the click-to-play poster for the demo video.
// Run MANUALLY from the site/ directory when the design changes,
// then commit the resulting src/assets/demo-poster.png (it is the
// committed source of truth; this script is not in the build):
//   node gen-poster.mjs
//
// A branded banner — the KiwiDesk wordmark on the site's dark
// green background — stands in for a real first frame (no ffmpeg
// in this environment). Swap for an actual frame later if wanted.
import sharp from "sharp";
import { readFileSync } from "node:fs";

const W = 1280;
const H = 720;

const bg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0" stop-color="#151e16"/>
      <stop offset="0.55" stop-color="#0d1512"/>
      <stop offset="1" stop-color="#0a100e"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.44" r="0.55">
      <stop offset="0" stop-color="#8db354" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#8db354" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#g)"/>
  <rect width="${W}" height="${H}" fill="url(#glow)"/>
</svg>`;

// The wordmark master (golden-on-transparent, for dark bg).
const wordmark = readFileSync("src/assets/brand/logo_wordmark_dark.svg");
const markHeight = 400;
const mark = await sharp(wordmark, { density: 300 })
  .resize({ height: markHeight })
  .png()
  .toBuffer();
const meta = await sharp(mark).metadata();

await sharp(Buffer.from(bg))
  .composite([
    {
      input: mark,
      left: Math.round((W - (meta.width ?? 0)) / 2),
      top: Math.round((H - markHeight) / 2),
    },
  ])
  .png()
  .toFile("src/assets/demo-poster.png");

console.log("wrote src/assets/demo-poster.png");
