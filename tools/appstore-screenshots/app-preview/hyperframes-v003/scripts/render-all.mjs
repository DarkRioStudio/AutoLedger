import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(readFileSync(path.join(root, "preview-manifest.json"), "utf8"));

execFileSync(process.execPath, ["scripts/sync-assets.mjs"], { cwd: root, stdio: "inherit" });
for (const locale of Object.keys(manifest.locales)) {
  execFileSync(process.execPath, ["scripts/render-locale.mjs", locale, "--check"], {
    cwd: root,
    stdio: "inherit",
  });
}
execFileSync(process.execPath, ["scripts/select-locale.mjs", "en-US"], {
  cwd: root,
  stdio: "inherit",
});

console.log("Rendered all five ASC 1.6.0 App Preview locale variants.");
