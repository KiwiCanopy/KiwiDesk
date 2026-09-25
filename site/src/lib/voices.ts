import type { ImageMetadata } from "astro";
import christefano from "../assets/voices/christefano.jpg";
import jeffMoore from "../assets/voices/jeff-moore.jpg";

/**
 * One user's words on the landing page's voices section.
 *
 * `quote` stays English on every locale — a translated testimonial
 * puts words in someone's mouth — so the page marks it `lang="en"`.
 * `avatar` is a local asset or `null` (a monogram is drawn); the
 * site's CSP allows no remote image, so never a URL. `link` points
 * at the person, not necessarily where they said it.
 */
export interface Voice {
  name: string;
  /** What they do; `null` when there is nothing to say. */
  role: string | null;
  quote: string;
  avatar: ImageMetadata | null;
  link: string;
  source: string;
}

export const voices: Voice[] = [
  {
    name: "Christefano",
    role: "Certified project manager & chess tutor",
    quote:
      "KiwiDesk is my go-to window manager. The developer is " +
      "responsive, friendly, and has a clear vision for the app. " +
      "And yet, KiwiDesk has so many options and is so flexible " +
      "that it immediately replaced the more opinionated window " +
      "managers I had.",
    avatar: christefano,
    link: "https://github.com/christefano",
    source: "GitHub",
  },
  {
    name: "Jeff Moore",
    role: "Educational administrator and author",
    quote:
      "KiwiDesk is the best tiling window manager on the Mac, " +
      "hands down! The more I use it and the more its feature set " +
      "grows, the less I find myself turning to Linux.",
    avatar: jeffMoore,
    link: "https://www.linkedin.com/in/jeff-moore-edd/",
    source: "LinkedIn",
  },
  {
    name: "Josh",
    role: "Engineer & vintage restorer",
    quote:
      "This is where people should start with macOS tiling " +
      "managers. While I love Rift and Amethyst — had I known this " +
      "existed, I would have never needed to go through the trial " +
      "and error.",
    avatar: null,
    link: "https://www.reddit.com/r/MacOS/s/mp0lqJx9uQ",
    source: "Reddit · r/MacOS",
  },
];

/** Initials for a voice without a picture: "Jeff Moore" → "JM". */
export const monogram = (name: string): string =>
  name
    .split(/\s+/)
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
