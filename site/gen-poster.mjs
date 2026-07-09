import sharp from "sharp";
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1c2417"/>
      <stop offset="0.55" stop-color="#243016"/>
      <stop offset="1" stop-color="#12240d"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.42" r="0.5">
      <stop offset="0" stop-color="#4e9f3d" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#4e9f3d" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1280" height="720" fill="url(#bg)"/>
  <rect width="1280" height="720" fill="url(#glow)"/>
  <circle cx="565" cy="300" r="86" fill="#8b5e3c"/>
  <circle cx="565" cy="300" r="68" fill="#c7e6a6"/>
  <circle cx="565" cy="300" r="25" fill="#f2ebd9"/>
  <text x="668" y="322" font-family="Helvetica,Arial,sans-serif" font-size="92" font-weight="700" fill="#f2ebd9">KiwiDesk</text>
  <text x="640" y="452" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="30" fill="#9fce8a">Tiling window management for macOS</text>
  <text x="640" y="620" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="22" fill="#6f7d64" letter-spacing="3">WATCH THE 10-SECOND DEMO</text>
</svg>`;
await sharp(Buffer.from(svg)).png().toFile("src/assets/demo-poster.png");
console.log("wrote src/assets/demo-poster.png");
