// KiwiDesk — shared inline layout diagrams.
//
// The six little SVG sketches (bsp, stack, scrolling, monocle,
// grid, floating) that illustrate each tiling layout. Extracted
// here so BOTH the marketing landing (Landing.astro, Developer
// mode "Layouts" grid) and the newcomer /learn/ page render the
// exact same drawings from one source — no redraw, no drift.
//
// Each returns an SVG string (viewBox 0 0 160 90) whose <rect>s
// carry the theme-aware .tile / .tile--accent / .tile--ghost
// classes from landing.css, so both pages tint correctly in
// light and dark.

export function layoutDiagram(name: string): string {
  const svg = (p: string) =>
    `<svg viewBox="0 0 160 90" preserveAspectRatio="none">${p}</svg>`;
  const r = (
    x: number,
    y: number,
    w: number,
    h: number,
    cls = "tile"
  ) =>
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" ` +
    `rx="4" class="${cls}"/>`;
  switch (name) {
    case "bsp":
      return svg(
        r(8, 8, 70, 74) +
          r(84, 8, 68, 34) +
          r(84, 48, 32, 34) +
          r(120, 48, 32, 34)
      );
    case "stack":
      return svg(
        r(8, 8, 92, 74, "tile tile--accent") +
          r(106, 8, 46, 22) +
          r(106, 34, 46, 22) +
          r(106, 60, 46, 22)
      );
    case "scrolling":
      return svg(
        r(-24, 8, 44, 74, "tile tile--ghost") +
          r(26, 8, 44, 74) +
          r(76, 8, 44, 74, "tile tile--accent") +
          r(126, 8, 44, 74) +
          r(176, 8, 44, 74, "tile tile--ghost")
      );
    case "monocle":
      return svg(
        r(20, 14, 120, 62, "tile tile--ghost") +
          r(14, 10, 120, 62, "tile tile--ghost") +
          r(8, 6, 120, 62, "tile tile--accent")
      );
    case "grid":
      return svg(
        r(8, 8, 44, 34) +
          r(58, 8, 44, 34) +
          r(108, 8, 44, 34) +
          r(8, 48, 44, 34) +
          r(58, 48, 44, 34) +
          r(108, 48, 44, 34)
      );
    case "floating":
      return svg(
        r(14, 12, 62, 44) +
          r(60, 34, 66, 46, "tile tile--accent") +
          r(96, 10, 52, 32)
      );
    default:
      return svg(r(8, 8, 144, 74));
  }
}
