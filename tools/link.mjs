// Links Interface/AddOns/OneKeyFishing to the OneKeyFishing/ folder of this repository, so every change is
// in the game after a /reload, without building. `--remove` deletes the link again (never a real folder).
// `--remove-copy` (npm's `prelink`, run before every `npm run link`) deletes an installed copy of the addon (a real
// folder with the addon's TOC, as `npm run install-addon` leaves it), so the link can take its place; a link or no
// folder is left alone.
// Windows uses a directory junction (no administrator rights needed); macOS and Linux use a symbolic link.
// An unbuilt addon shows its version as "dev".
import fs from "node:fs";
import path from "node:path";
import { ADDON, ADDON_DIR, fail, installTarget, isLink } from "./addon.mjs";

const target = installTarget();
const remove = process.argv.includes("--remove");

if (process.argv.includes("--remove-copy")) {
  if (!isLink(target) && fs.existsSync(target)) {
    if (!fs.existsSync(path.join(target, `${ADDON}.toc`))) {
      fail(`"${target}" is a folder without ${ADDON}.toc; not deleting it, check what it is`);
    }
    fs.rmSync(target, { recursive: true, force: true });
    console.log(`Removed the installed copy ${target}`);
  }
  process.exit(0);
}

if (isLink(target)) {
  fs.rmSync(target); // removes the link itself, not the folder it points to
  if (remove) {
    console.log(`Removed the link ${target}`);
    process.exit(0);
  }
} else if (fs.existsSync(target)) {
  fail(`"${target}" is a real folder (an installed copy); \`npm run link\` deletes it first (prelink)`);
} else if (remove) {
  console.log(`No link at ${target}`);
  process.exit(0);
}

fs.symlinkSync(ADDON_DIR, target, process.platform === "win32" ? "junction" : "dir");
console.log(`Linked ${target}`);
console.log(`     -> ${ADDON_DIR}`);
console.log("Restart the game once; after that a /reload picks up changes to existing files.");
