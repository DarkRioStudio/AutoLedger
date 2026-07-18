import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(readFileSync(path.join(root, "preview-manifest.json"), "utf8"));
const screenshotConfig = JSON.parse(
  readFileSync(path.resolve(root, "../../config/screenshots.json"), "utf8")
);
const requestedLocale = process.argv[2] || "en-US";
const locale = manifest.locales[requestedLocale];

if (!locale) {
  throw new Error(`Unsupported locale ${requestedLocale}. Use: ${Object.keys(manifest.locales).join(", ")}`);
}

const escapeHTML = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const values = {
  HTML_LANG: locale.htmlLang,
  LOCALE_CLASS: locale.localeClass,
  ACTIVE_LOCALE: requestedLocale,
  DEMO_DISCLOSURE: locale.demoDisclosure,
  PRO_DISCLOSURE: locale.proDisclosure,
  PRO_MASK_LABEL: locale.proMaskLabel,
  FINAL_TITLE: locale.finalTitle,
  FINAL_SUBTITLE: locale.finalSubtitle,
};

for (const scene of manifest.scenes) {
  const shot = screenshotConfig.iosShots.find((candidate) => candidate.id === scene.shotId);
  if (!shot) {
    throw new Error(`Missing iOS shot configuration for ${scene.shotId}`);
  }
  const prefix = `SCENE_${scene.key.toUpperCase()}`;
  values[`${prefix}_TITLE`] = shot.title[locale.assetLocale];
  values[`${prefix}_SUBTITLE`] = shot.subtitle[locale.assetLocale];
  values[`${prefix}_INDEX`] = scene.index;
  values[`${prefix}_ASSET`] = `assets/${locale.assetLocale}/${scene.shotId}.png`;
}

let html = readFileSync(path.join(root, "composition.template"), "utf8");
for (const [key, value] of Object.entries(values)) {
  html = html.replaceAll(`{{${key}}}`, escapeHTML(value));
}

const unresolved = [...html.matchAll(/\{\{[A-Z0-9_]+\}\}/g)].map((match) => match[0]);
if (unresolved.length > 0) {
  throw new Error(`Unresolved template values: ${[...new Set(unresolved)].join(", ")}`);
}

writeFileSync(path.join(root, "index.html"), html);
writeFileSync(
  path.join(root, "active-locale.json"),
  `${JSON.stringify({ locale: requestedLocale, assetLocale: locale.assetLocale }, null, 2)}\n`
);
console.log(`Selected App Preview locale ${requestedLocale} (${locale.assetLocale}).`);
