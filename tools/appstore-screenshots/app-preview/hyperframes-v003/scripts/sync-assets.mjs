import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const screenshotRoot = path.resolve(root, "../../output/raw/ios");
const manifest = JSON.parse(
  await import("node:fs/promises").then(({ readFile }) =>
    readFile(path.join(root, "preview-manifest.json"), "utf8")
  )
);

mkdirSync(path.join(root, "assets"), { recursive: true });

for (const locale of Object.values(manifest.locales)) {
  const destination = path.join(root, "assets", locale.assetLocale);
  mkdirSync(destination, { recursive: true });

  for (const scene of manifest.scenes) {
    const source = path.join(screenshotRoot, locale.assetLocale, `${scene.shotId}.png`);
    if (!existsSync(source)) {
      throw new Error(
        `Missing ${source}. Export it first with: bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale ${locale.assetLocale}`
      );
    }
    copyFileSync(source, path.join(destination, `${scene.shotId}.png`));
  }
}

copyFileSync(
  path.resolve(root, "../hyperframes-v002/assets/app_icon.png"),
  path.join(root, "assets/app_icon.png")
);

const scoreManifest = path.join(root, "score-manifest.json");
const sourceBed = path.join(root, "assets/app_preview_score_v003.wav");
const outputBed = path.join(root, "assets/app_preview_bed_v003.m4a");
execFileSync(
  "python3",
  [path.join(root, "scripts/generate-score.py"), "--manifest", scoreManifest, "--output", sourceBed],
  { stdio: "inherit" }
);
execFileSync(
  "ffmpeg",
  [
    "-y",
    "-i",
    sourceBed,
    "-filter:a",
    "atrim=duration=22,loudnorm=I=-20:TP=-1.5:LRA=7,afade=t=in:st=0:d=0.5,afade=t=out:st=21.2:d=0.8",
    "-c:a",
    "aac",
    "-b:a",
    "256k",
    "-ar",
    "48000",
    "-ac",
    "2",
    outputBed,
  ],
  { stdio: "inherit" }
);

console.log("Synced five-locale UI captures, app icon, and original 22-second delivery score.");
