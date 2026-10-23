// Copies the built dist/OneKeyFishing into the game's Interface/AddOns folder, replacing the previous copy.
// The AddOns folder comes from WOW_ADDONS_DIR (environment or .env file, see .env.example).
import fs from "node:fs";
import path from "node:path";
import { ADDON, DIST, fail, installTarget, isLink } from "./addon.mjs";

const source = path.join(DIST, ADDON);
if (!fs.existsSync(source)) {
  fail("nothing to install: run `npm run dev` or `npm run build` first");
}

const target = installTarget();
if (isLink(target)) {
  fail(`"${target}" is a link to your working folder (npm run link); run \`npm run unlink\` first`);
}
fs.rmSync(target, { recursive: true, force: true });
fs.cpSync(source, target, { recursive: true });
console.log(`Installed ${ADDON} into ${target}`);
console.log("Type /reload in the game. Restart the game instead if files were added or the TOC changed.");
