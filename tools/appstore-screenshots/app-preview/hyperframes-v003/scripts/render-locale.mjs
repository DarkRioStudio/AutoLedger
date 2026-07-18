import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(readFileSync(path.join(root, "preview-manifest.json"), "utf8"));
const locale = process.argv[2];
const shouldCheck = process.argv.includes("--check");

if (!locale || !manifest.locales[locale]) {
  throw new Error(`Pass one locale: ${Object.keys(manifest.locales).join(", ")}`);
}

const run = (command, args) => execFileSync(command, args, { cwd: root, stdio: "inherit" });
run(process.execPath, ["scripts/select-locale.mjs", locale]);

if (shouldCheck) {
  run("npx", ["--yes", "hyperframes@0.6.109", "lint"]);
  run("npx", ["--yes", "hyperframes@0.6.109", "validate"]);
  run("npx", ["--yes", "hyperframes@0.6.109", "inspect", "--samples", "15"]);
}

const reviewDir = path.join(root, "renders/review");
const finalDir = path.join(root, "renders/final");
mkdirSync(reviewDir, { recursive: true });
mkdirSync(finalDir, { recursive: true });

const baseName = `app_preview_iphone_${locale}_${manifest.version}`;
const reviewPath = path.join(reviewDir, `${baseName}_review.mp4`);
const finalPath = path.join(finalDir, `${baseName}.mp4`);

run("npx", [
  "--yes",
  "hyperframes@0.6.109",
  "render",
  "--output",
  reviewPath,
  "--fps",
  "30",
  "--quality",
  "high",
]);

run("ffmpeg", [
  "-y",
  "-i",
  reviewPath,
  "-i",
  path.join(root, "assets/app_preview_bed_v003.m4a"),
  "-map",
  "0:v:0",
  "-map",
  "1:a:0",
  "-c:v",
  "libx264",
  "-profile:v",
  "high",
  "-level:v",
  "4.0",
  "-pix_fmt",
  "yuv420p",
  "-r",
  "30",
  "-b:v",
  "11M",
  "-minrate",
  "11M",
  "-maxrate",
  "11M",
  "-bufsize",
  "22M",
  "-x264-params",
  "nal-hrd=cbr:force-cfr=1",
  "-c:a",
  "aac",
  "-b:a",
  "256k",
  "-ar",
  "48000",
  "-ac",
  "2",
  "-shortest",
  "-movflags",
  "+faststart",
  finalPath,
]);

console.log(`Rendered ${locale}: ${finalPath}`);
