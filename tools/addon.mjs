// Shared helpers for the check, build, install and link scripts.
// Repository layout: the addon itself lives in OneKeyFishing/ (exactly what goes into Interface/AddOns);
// tools, docs and project files stay in the repository root.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ADDON = "OneKeyFishing";
export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const ADDON_DIR = path.join(ROOT, ADDON);
export const DIST = path.join(ROOT, "dist");
export const TOC = `${ADDON}.toc`;

// Packaged next to the files listed in the TOC: from the addon folder (Bindings.xml is loaded by the client
// by its name) and from the repository root.
export const ADDON_EXTRAS = ["Bindings.xml"];
export const ROOT_EXTRAS = ["LICENSE", "README.md", "CHANGELOG.md"];

// Parses a TOC: `## Key: Value` metadata and the list of files (as forward-slash paths).
export function parseToc(text) {
  const fields = {};
  const files = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "") {
      continue;
    }
    const field = line.match(/^##\s*([^:]+):\s*(.*)$/);
    if (field) {
      fields[field[1].trim()] = field[2].trim();
    } else if (!line.startsWith("#")) {
      files.push(line.replace(/\\/g, "/"));
    }
  }
  return { fields, files };
}

// Every packaged file: `from` is relative to the repository root, `to` to the addon folder in the package.
export function packageEntries(tocText) {
  const addonFiles = [TOC, ...parseToc(tocText).files, ...ADDON_EXTRAS];
  return [
    ...addonFiles.map((file) => ({ from: `${ADDON}/${file}`, to: file })),
    ...ROOT_EXTRAS.map((file) => ({ from: file, to: file })),
  ];
}

export function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

// The game's Interface/AddOns folder: the WOW_ADDONS_DIR environment variable, or the same line in a
// git-ignored `.env` file in the repository root (see `.env.example`).
export function addonsDir() {
  let dir = process.env.WOW_ADDONS_DIR;
  const envFile = path.join(ROOT, ".env");
  if (!dir && fs.existsSync(envFile)) {
    for (const line of fs.readFileSync(envFile, "utf8").split(/\r?\n/)) {
      const match = line.match(/^\s*WOW_ADDONS_DIR\s*=\s*(.*?)\s*$/);
      if (match) {
        dir = match[1].replace(/^(["'])(.*)\1$/, "$2");
      }
    }
  }
  if (!dir) {
    fail("set WOW_ADDONS_DIR in a .env file (copy .env.example) or in the environment");
  }
  dir = path.resolve(dir);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    fail(`WOW_ADDONS_DIR "${dir}" is not a folder`);
  }
  // Only ever touch a folder inside a real AddOns folder.
  if (path.basename(dir).toLowerCase() !== "addons" || path.basename(path.dirname(dir)).toLowerCase() !== "interface") {
    fail(`WOW_ADDONS_DIR "${dir}" does not look like .../Interface/AddOns`);
  }
  return dir;
}

// Interface/AddOns/OneKeyFishing, checked not to be (or contain) the repository.
export function installTarget() {
  const target = path.join(addonsDir(), ADDON);
  const relToTarget = path.relative(target, ROOT);
  if (relToTarget === "" || (!relToTarget.startsWith("..") && !path.isAbsolute(relToTarget))) {
    fail(`"${target}" is the repository (or contains it); point WOW_ADDONS_DIR at the game's AddOns folder`);
  }
  return target;
}

export function isLink(file) {
  try {
    return fs.lstatSync(file).isSymbolicLink();
  } catch {
    return false;
  }
}
