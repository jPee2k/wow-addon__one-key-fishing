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
// by its name; README.md is the player manual) and from the repository root (the root README.md is the
// developer page and stays out of the package).
export const ADDON_EXTRAS = ["Bindings.xml", "README.md"];
export const ROOT_EXTRAS = ["LICENSE", "CHANGELOG.md"];

// The addon's folders, one per area of docs/architecture/ (and of tests/); every TOC file is under one of them.
export const ADDON_FOLDERS = [
  "Core", "Locales", "GameData", "Fishing", "Catch", "CatchDB", "Exchange", "Catalog", "UI",
];
// The layers (docs/architecture/core.md, "Layers"): a file may use the module tables (`ns.<Name>`) of its own
// layer and the ones below. Core/Commands.lua is the entry that may open a window, so it sees everything;
// Core/Debug.lua and Core/Spike.lua report on every module but the UI. What a file defines counts with its folder.
export const LAYERS = {
  Core: 0, Locales: 0, GameData: 0, Fishing: 1, Catch: 1, CatchDB: 2, Exchange: 2, Catalog: 2, UI: 3,
};
export const ENTRY_LAYERS = { "Core/Commands.lua": 3, "Core/Debug.lua": 2, "Core/Spike.lua": 2 };
// Frames are the UI's; outside UI/ only these make one: the event frame, the secure button and its state handler
// (the controller must own them), the scanning tooltip, and the spike's template probes.
export const FRAMES_OUTSIDE_UI = ["Core/Core.lua", "Fishing/Action.lua", "Fishing/Gear.lua", "Core/Spike.lua"];
// Files the tools name on their own (paths inside the addon folder, forward slashes).
export const LOCALES_DIR = "Locales";
export const BASE_LOCALE = "Locales/enUS.lua";
export const SEED_FILE = "CatchDB/SeedData.lua"; // written by npm run harvest
export const COMMANDS_FILE = "Core/Commands.lua"; // ns.COMMANDS, every slash command

export const MAX_LINE_LENGTH = 120;

// Verification debt: `-- VERIFY(<id>): <what>` marks addon code built on an assumption not yet checked in game
// (the feature's verification.md lists them). `npm run check` lists them; `npm run check -- --release` (run by
// `npm run build` and the release workflow) fails on them.
const VERIFY_MARKER = /VERIFY\(([^)]+)\):?\s*(.*)$/;

// The markers of one file's text: { line, id, what }.
export function findMarkers(text) {
  const markers = [];
  text.split(/\r?\n/).forEach((line, index) => {
    const match = line.match(VERIFY_MARKER);
    if (match) {
      markers.push({ line: index + 1, id: match[1], what: match[2] });
    }
  });
  return markers;
}

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
// git-ignored `.env` file in the repository root (see `.env.example`). With `optional`, null when it is not set.
export function addonsDir({ optional = false } = {}) {
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
    if (optional) {
      return null;
    }
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
