// Génère les icônes PWA (PNG) à partir d'un SVG : npm run icons
import sharp from "sharp";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(root, "public", "icons");
mkdirSync(out, { recursive: true });

// Deux personnes stylisées sur un dégradé indigo → violet
function svg({ size = 512, rounded = true, pad = 0, mono = false }) {
  const s = 512;
  const scale = (s - 2 * pad) / s;
  const bg = mono
    ? ""
    : `<rect width="${s}" height="${s}" rx="${rounded ? 112 : 0}" fill="url(#g)"/>`;
  const fill = mono ? "#ffffff" : "#ffffff";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${s} ${s}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6366f1"/>
      <stop offset="1" stop-color="#7c3aed"/>
    </linearGradient>
  </defs>
  ${bg}
  <g transform="translate(${pad} ${pad}) scale(${scale})">
    <circle cx="196" cy="190" r="62" fill="${fill}" opacity="0.96"/>
    <path d="M86 378c0-66 50-112 110-112s110 46 110 112v14H86z" fill="${fill}" opacity="0.96"/>
    <circle cx="336" cy="208" r="50" fill="${fill}" opacity="0.72"/>
    <path d="M250 392c0-56 40-94 86-94s86 38 86 94v6H250z" fill="${fill}" opacity="0.72"/>
    <circle cx="388" cy="124" r="34" fill="#fb7185"/>
    <path d="M374 118l10 10 20-20" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  </g>
</svg>`;
}

const jobs = [
  ["icon-192.png", { size: 192 }],
  ["icon-512.png", { size: 512 }],
  ["maskable-512.png", { size: 512, rounded: false, pad: 56 }],
  ["apple-touch-icon.png", { size: 180, rounded: false }],
  ["badge-96.png", { size: 96, mono: true, pad: 40 }],
];

for (const [name, opts] of jobs) {
  const buf = await sharp(Buffer.from(svg(opts))).png().toBuffer();
  writeFileSync(join(out, name), buf);
  console.log("✓", name);
}
// favicon (app/icon.png est servi automatiquement par Next.js)
const fav = await sharp(Buffer.from(svg({ size: 64 }))).png().toBuffer();
writeFileSync(join(root, "app", "icon.png"), fav);
console.log("✓ app/icon.png");
