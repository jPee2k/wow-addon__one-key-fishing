// Shared helpers for the check, build, install and link scripts.
// Repository layout: the addon itself lives in OneKeyFishing/ (exactly what goes into Interface/AddOns);
// tools, docs and project files stay in the repository root.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import luaparse from "luaparse";

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

// GameData/ holds data only (docs/architecture/game-data.md): its code has no function, no call, no L lookup and
// names no module but ns.GameData. Only the code is read: string literals and comments (line and block) are left out, so
// official names and explanations may say anything. Returns { line, message } per offending line.
const GAMEDATA_MESSAGE = "GameData/ holds data only (no function, no call, no ns.L, no other module)";
const LUA_TOKEN = /--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|\[(=*)\[[\s\S]*?\]\2\]/g;
const LUA_KEYWORDS = new Set(["and", "or", "not", "return", "in", "then", "do", "else", "elseif", "until", "local"]);
export function gameDataProblems(text) {
  // Blank every comment and string, keeping the line breaks so the line numbers stay.
  const code = text.replace(LUA_TOKEN, (token) =>
    token.startsWith("--") ? token.replace(/[^\n]/g, " ") : `""${token.replace(/[^\n]/g, "")}`);
  const problems = [];
  code.split(/\r?\n/).forEach((line, index) => {
    const modules = [...line.matchAll(/\bns\.([A-Za-z_]\w*)/g)].map((match) => match[1]);
    // A call: a name, a field or a closing bracket followed by "(", or by a table or a string (Lua's calls without
    // brackets: f{...}, f"x"), or a method (a:b). Data puts "=" or "," before every table and string.
    const call = [...line.matchAll(/([A-Za-z_]\w*|[\])])\s*(?:[({]|"")/g)].some((m) => !LUA_KEYWORDS.has(m[1]))
      || /\w\s*:\s*[A-Za-z_]/.test(line);
    if (/\bfunction\b/.test(line) || call || /(^|[^\w.])L\s*\[/.test(line) || /\bns\s*\[/.test(line)
      || modules.some((name) => name !== "GameData")) {
      problems.push({ line: index + 1, message: GAMEDATA_MESSAGE });
    }
  });
  return problems;
}

// A module's private table (`<Module>.private`) holds what the files of that module share and what only the tests
// read (docs/development.md); no file of another folder reads it. folderOf(name) gives the folder that defines the
// module `ns.<name>`, or undefined. Returns { line, message } per offending use. The file is parsed (luaparse), so
// comments and strings are not read, and a read through a local alias (`local C = ns.CatchDB` ... `C.private`) or a
// bracketed name (`ns["CatchDB"].private`, `C["private"]`) is found too (spec 012). A file that does not parse gives no problems:
// the check's own parse step reports it.
export function privateProblems(text, folder, folderOf) {
  if (!text.includes("private")) {
    return []; // no read is possible: spares a second parse of most files (the bundled seed among them)
  }
  let ast;
  try {
    ast = luaparse.parse(text, { luaVersion: "5.1", locations: true, comments: false });
  } catch {
    return [];
  }
  const aliases = new Map(); // local name -> module name
  const stringValue = (node) => node.type === "StringLiteral" ? node.raw.slice(1, -1) : undefined;
  // The module a value names: `X` (a known module or an alias), `ns.X` or `ns["X"]`; else undefined.
  const moduleOf = (node) => {
    if (!node) {
      return undefined;
    }
    if (node.type === "Identifier") {
      return aliases.get(node.name) ?? (folderOf(node.name) !== undefined ? node.name : undefined);
    }
    const isNs = node.base && node.base.type === "Identifier" && node.base.name === "ns";
    if (node.type === "MemberExpression" && node.indexer === "." && isNs) {
      return folderOf(node.identifier.name) !== undefined ? node.identifier.name : undefined;
    }
    if (node.type === "IndexExpression" && isNs) {
      const name = stringValue(node.index);
      return name !== undefined && folderOf(name) !== undefined ? name : undefined;
    }
    return undefined;
  };
  const problems = [];
  const visit = (node) => {
    if (!node || typeof node !== "object") {
      return;
    }
    if (Array.isArray(node)) {
      node.forEach(visit);
      return;
    }
    if (node.type === "LocalStatement" || node.type === "AssignmentStatement") {
      node.init.forEach(visit);
      node.variables.forEach((variable, i) => {
        if (variable.type === "Identifier") {
          const name = moduleOf(node.init[i]);
          if (name !== undefined) {
            aliases.set(variable.name, name);
          } else {
            aliases.delete(variable.name);
          }
        } else {
          visit(variable);
        }
      });
      return;
    }
    const readsPrivate = (node.type === "MemberExpression" && node.identifier.name === "private")
      || (node.type === "IndexExpression" && stringValue(node.index) === "private");
    if (readsPrivate) {
      const name = moduleOf(node.base);
      const owner = name !== undefined ? folderOf(name) : undefined;
      if (owner !== undefined && owner !== folder) {
        problems.push({ line: node.loc.start.line,
          message: `reads ${name}.private of ${owner}/ (a module's private table is not an API)` });
      }
    }
    for (const [key, value] of Object.entries(node)) {
      if (key !== "loc" && key !== "range") {
        visit(value);
      }
    }
  };
  visit(ast.body);
  return problems;
}

// The tests are grouped by area (docs/development.md): a test folder names its addon folder, and a test file names
// its subject, never a module of that folder (`fishing/lure_skill_test.lua`, not `fishing/bags_test.lua`).
export const TEST_FOLDERS = {
  core: "Core", fishing: "Fishing", catch: "Catch", catchdb: "CatchDB", catalog: "Catalog", exchange: "Exchange",
  ui: "UI", gamedata: "GameData",
};
const TEST_NAME_MESSAGE = "test named after a module of its area; name its subject (docs/development.md)";
// testPath: relative to tests/ with forward slashes; moduleFiles(folder): the .lua base names of an addon folder.
// Returns the problem text or null.
export function testNameProblem(testPath, moduleFiles) {
  const match = testPath.match(/^([^/]+)\/(?:.*\/)?([^/]+)_test\.lua$/);
  const folder = match && TEST_FOLDERS[match[1]];
  if (!folder) {
    return null;
  }
  const name = match[2].toLowerCase();
  return moduleFiles(folder).some((file) => file.toLowerCase() === name) ? TEST_NAME_MESSAGE : null;
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
