// Derives the PUBLIC half of a Sparkle EdDSA signing key from the
// private key on stdin, and prints it base64 — the exact form
// `SUPublicEDKey` takes in a bundle's Info.plist.
//
// It exists so `release.yml` can answer one question before it
// signs anything: is `SPARKLE_PRIVATE_KEY` the key this app
// actually trusts? Signing with a key and then verifying with the
// same key proves the secret is self-consistent and nothing more.
// A valid but WRONG key passes that check, produces a perfectly
// well-formed signature, and ships an update that every installed
// copy refuses — discovered by users, one release later, with no
// way to reach them (docs/design-decisions.md, "No distribution
// channel without an update path").
//
// Node rather than openssl: `openssl` on a macOS runner is
// LibreSSL, which has no Ed25519 support at all (`unsupported
// algorithm`, checked against LibreSSL 3.3.6). Node ships in the
// runner image and does Ed25519 natively, which beats
// hand-rolling curve arithmetic inside a release pipeline.
//
// SparkleKeyDerivationTests pins this against RFC 8032's first
// test vector, so the derivation is checked against the standard
// rather than against itself.

const crypto = require("crypto");
const fs = require("fs");

// The read can fail; the DECODE cannot. Node's base64 decoder
// never throws — it silently drops anything outside the
// alphabet — so a catch reporting "not base64" would be
// unreachable, and reporting it as the reason would be a lie
// about which check found the problem. The length test below is
// what actually rejects garbage.
let raw;
try {
  raw = Buffer.from(fs.readFileSync(0, "utf8").trim(), "base64");
} catch (error) {
  console.error(`sparkle-public-key: could not read stdin: ${error.message}`);
  process.exit(1);
}

// 32 bytes is the current format — the private seed, which is
// what `generate_keys -x` exports. 64 is the legacy format, seed
// followed by the public half; the seed still leads, so the same
// derivation covers both and cross-checks the tail.
if (raw.length !== 32 && raw.length !== 64) {
  console.error(
    `sparkle-public-key: key decodes to ${raw.length} bytes; ` +
      "expected 32 (a seed) or 64 (legacy seed+public)"
  );
  process.exit(1);
}

const seed = raw.subarray(0, 32);
// PKCS#8 wrapper for an Ed25519 private key: the fixed prefix
// below is the ASN.1 header, and the seed is the whole payload.
const der = Buffer.concat([
  Buffer.from("302e020100300506032b657004220420", "hex"),
  seed,
]);

let spki;
try {
  spki = crypto
    .createPublicKey(
      crypto.createPrivateKey({ key: der, format: "der", type: "pkcs8" })
    )
    .export({ format: "der", type: "spki" });
} catch (error) {
  console.error(`sparkle-public-key: ${error.message}`);
  process.exit(1);
}

// The raw 32-byte public key is the tail of the SPKI structure.
const derived = spki.subarray(spki.length - 32);

if (raw.length === 64) {
  const carried = raw.subarray(32);
  if (!crypto.timingSafeEqual(derived, carried)) {
    console.error(
      "sparkle-public-key: this legacy key's public half does " +
        "not match its own seed — the secret is corrupt"
    );
    process.exit(1);
  }
}

console.log(derived.toString("base64"));
