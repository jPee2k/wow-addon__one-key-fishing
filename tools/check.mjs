// Static checks for the addon (no Lua or luacheck needed):
//   Lua 5.1 syntax, undeclared and unused globals against .luacheckrc, line length (also of tests/*.lua),
//   ASCII-only Lua, TOC and XML files (translations excepted), the addon folder holds only packaged files, the
//   repository root is packaged or ignored in .pkgmeta, TOC file list, locale keys, and the version in
//   package.json vs CHANGELOG.md.
import fs from "node:fs";
import path from "node:path";
import luaparse from "luaparse";
import { ADDON, ROOT, ADDON_DIR, TOC, ADDON_EXTRAS, ROOT_EXTRAS, parseToc } from "./addon.mjs";

const MAX_LINE_LENGTH = 120;
// Git-ignored local folders and files (editor settings, the local AddOns path) are not part of the project.
const SKIP_DIRS = new Set([".git", "node_modules", "dist", ".release", ".vscode", ".idea"]);
const SKIP_FILES = new Set([".env"]);
// Globals of the Lua runtime itself; WoW API names belong in .luacheckrc.
const LUA_BUILTINS = new Set(("_G assert error ipairs pairs next pcall print select tonumber tostring type unpack " +
  "math string table os coroutine setmetatable getmetatable rawget rawset rawequal xpcall").split(" "));

const NON_ASCII = /[^\x00-\x7f]/;

const problems = [];
const problem = (where, message) => problems.push(`${where}: ${message}`);
const rel = (file) => path.relative(ROOT, file).split(path.sep).join("/");
// Path inside the addon folder, as the TOC writes it.
const relAddon = (file) => path.relative(ADDON_DIR, file).split(path.sep).join("/");
const inAddon = (file) => rel(file).startsWith(`${ADDON}/`);
// The Lua tests and their stubs (npm test) are the only Lua files allowed outside the addon folder.
const inTests = (file) => rel(file).startsWith("tests/");

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) {
        walk(path.join(dir, entry.name), out);
      }
    } else if (!SKIP_FILES.has(entry.name)) {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

// Names inside `globals = { ... }` and `read_globals = { ... }`.
function declaredGlobals() {
  const rc = fs.readFileSync(path.join(ROOT, ".luacheckrc"), "utf8");
  const names = new Map();
  for (const block of rc.matchAll(/^(globals|read_globals)\s*=\s*\{([\s\S]*?)^\}/gm)) {
    const body = block[2].replace(/--[^\n]*/g, "");
    for (const match of body.matchAll(/"([A-Za-z_][A-Za-z0-9_]*)"/g)) {
      if (names.has(match[1])) {
        problem(".luacheckrc", `"${match[1]}" is declared twice`);
      }
      names.set(match[1], block[1]);
    }
  }
  return names;
}

const files = walk(ROOT);
const luaFiles = files.filter((file) => file.endsWith(".lua") && inAddon(file));
for (const file of files.filter((f) => f.endsWith(".lua") && !inAddon(f) && !inTests(f))) {
  problem(rel(file), `Lua file outside ${ADDON}/`);
}
const declared = declaredGlobals();
const used = new Set();

// The release packager (BigWigsMods/packager) replaces keywords such as @project-version@ or @file-hash@ and
// strips or comments out --@debug@ / --@retail@ ... --@end-...@ blocks in every packaged file, not only in the
// TOC, so the release would differ from the working folder. Only the TOC may use them.
const PACKAGER_KEYWORD = /@(project|file)-[a-z-]+@|--\s*@(end-)?[a-z-]+@/;

function checkPackagerKeywords(file, lines) {
  lines.forEach((line, i) => {
    if (PACKAGER_KEYWORD.test(line)) {
      problem(`${rel(file)}:${i + 1}`, "packager keyword or directive (the release build would change it)");
    }
  });
}

// A font file set with SetFont draws only the scripts that file has (also through a variable or
// STANDARD_TEXT_FONT); the game's font objects (GameFontNormal, ... through a template or SetFontObject) pick a
// Korean, Chinese or Cyrillic font when the text needs it, so the translations stay readable.
const SET_FONT = /[:.]SetFont\s*\(/;

function checkFontPaths(file, lines) {
  lines.forEach((line, i) => {
    if (SET_FONT.test(line)) {
      problem(`${rel(file)}:${i + 1}`, "SetFont (use the game's font objects: a template or SetFontObject)");
    }
  });
}

// Lua 5.1 syntax and line length (and packager keywords and font paths in addon files); returns the parsed
// chunk, or null after a syntax error.
function parseLua(file) {
  const source = fs.readFileSync(file, "utf8");
  const lines = source.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.length > MAX_LINE_LENGTH) {
      problem(`${rel(file)}:${i + 1}`, `line is ${line.length} characters long (max ${MAX_LINE_LENGTH})`);
    }
  });
  if (inAddon(file)) {
    checkPackagerKeywords(file, lines);
    checkFontPaths(file, lines);
  }
  try {
    return luaparse.parse(source, { luaVersion: "5.1", scope: true });
  } catch (err) {
    problem(rel(file), `syntax error: ${err.message}`);
    return null;
  }
}

for (const file of luaFiles) {
  const ast = parseLua(file);
  for (const name of new Set(ast ? ast.globals.map((g) => g.name) : [])) {
    used.add(name);
    if (!declared.has(name) && !LUA_BUILTINS.has(name)) {
      problem(rel(file), `undeclared global "${name}" (add it to .luacheckrc)`);
    }
  }
}

// The tests run in fengari with their own stub globals: syntax and line length only.
for (const file of files.filter((f) => f.endsWith(".lua") && inTests(f))) {
  parseLua(file);
}

for (const [name, kind] of declared) {
  if (!used.has(name)) {
    problem(".luacheckrc", `${kind} "${name}" is not used by any file`);
  }
}

for (const file of files.filter((f) => f.endsWith(".xml") && inAddon(f))) {
  checkPackagerKeywords(file, fs.readFileSync(file, "utf8").split(/\r?\n/));
}

// Lua, TOC and XML files are plain ASCII. Translations are the exception: Locales/<code>.lua (all but enUS.lua)
// is UTF-8 text in its own language.
const isTranslation = (file) =>
  inAddon(file) && relAddon(file).startsWith("Locales/") && relAddon(file) !== "Locales/enUS.lua";
for (const file of files) {
  if (![".lua", ".toc", ".xml"].includes(path.extname(file).toLowerCase()) || isTranslation(file)) {
    continue;
  }
  fs.readFileSync(file, "utf8").split(/\r?\n/).forEach((line, i) => {
    if (NON_ASCII.test(line)) {
      problem(`${rel(file)}:${i + 1}`, "non-ASCII character (Lua, TOC and XML files are plain ASCII)");
    }
  });
}

// TOC: every listed file exists, the addon folder holds nothing that is not packaged, the version is filled
// in at build time.
const tocName = `${ADDON}/${TOC}`;
const tocPath = path.join(ADDON_DIR, TOC);
if (!fs.existsSync(tocPath)) {
  problem(tocName, "missing");
} else {
  const toc = parseToc(fs.readFileSync(tocPath, "utf8"));
  const packaged = new Set([TOC, ...toc.files, ...ADDON_EXTRAS]);
  for (const file of [...toc.files, ...ADDON_EXTRAS]) {
    if (!fs.existsSync(path.join(ADDON_DIR, file))) {
      problem(tocName, `"${ADDON}/${file}" does not exist`);
    }
  }
  for (const file of ROOT_EXTRAS) {
    if (!fs.existsSync(path.join(ROOT, file))) {
      problem(file, "missing (it is packaged with the addon)");
    }
  }
  for (const file of files.filter(inAddon)) {
    if (!packaged.has(relAddon(file))) {
      problem(rel(file), `not listed in ${TOC}, so it would not be packaged`);
    }
  }
  for (const field of ["Interface", "Title", "Notes", "Author", "Version"]) {
    if (!toc.fields[field]) {
      problem(tocName, `missing "## ${field}"`);
    }
  }
  if (toc.fields.Version && toc.fields.Version !== "@project-version@") {
    problem(tocName, `"## Version" must be @project-version@ (the version comes from package.json)`);
  }
}

// The release packager copies the whole repository root into the package folder (package-as and move-folders
// share the name), so every root entry must be packaged on purpose or listed in the .pkgmeta ignore list.
// Dotfiles are skipped by the packager itself, git-ignored folders are not in its checkout.
const pkgmeta = fs.readFileSync(path.join(ROOT, ".pkgmeta"), "utf8");
const ignoreBlock = pkgmeta.match(/^ignore:\s*\n((?:[ \t]+-[^\n]*\n?)*)/m);
const ignored = new Set(ignoreBlock ? [...ignoreBlock[1].matchAll(/-\s*(\S+)/g)].map((m) => m[1]) : []);
const packagedRoot = new Set([ADDON, ...ROOT_EXTRAS]);
for (const entry of fs.readdirSync(ROOT)) {
  if (entry.startsWith(".") || SKIP_DIRS.has(entry) || SKIP_FILES.has(entry)) {
    continue;
  }
  if (!packagedRoot.has(entry) && !ignored.has(entry)) {
    problem(entry, "would be packaged: add it to the ignore list in .pkgmeta");
  }
}
for (const entry of packagedRoot) {
  if (ignored.has(entry)) {
    problem(".pkgmeta", `"${entry}" is packaged, it must not be ignored`);
  }
}

// Locales: every L["..."] used in the code is listed in enUS.lua, and every listed key is used.
// Other locales may only translate keys that exist in enUS.lua.
const L_KEY = /\bL\["((?:[^"\\]|\\.)*)"\]/g;
const keysIn = (file) => new Set([...fs.readFileSync(file, "utf8").matchAll(L_KEY)].map((m) => m[1]));
const baseLocale = path.join(ADDON_DIR, "Locales", "enUS.lua");
const baseName = rel(baseLocale);
const isLocale = (file) => relAddon(file).startsWith("Locales/");
if (!fs.existsSync(baseLocale)) {
  problem(baseName, "missing");
} else {
  const baseKeys = keysIn(baseLocale);
  const usedKeys = new Set();
  for (const file of luaFiles.filter((f) => !isLocale(f))) {
    for (const key of keysIn(file)) {
      usedKeys.add(key);
      if (!baseKeys.has(key)) {
        problem(rel(file), `L["${key}"] is not listed in ${baseName}`);
      }
    }
  }
  for (const key of baseKeys) {
    if (!usedKeys.has(key)) {
      problem(baseName, `L["${key}"] is not used by any file`);
    }
  }
  for (const file of luaFiles.filter((f) => isLocale(f) && f !== baseLocale)) {
    for (const key of keysIn(file)) {
      if (!baseKeys.has(key)) {
        problem(rel(file), `L["${key}"] does not exist in ${baseName}`);
      }
    }
  }
}

// The newest CHANGELOG entry matches package.json.
const version = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8")).version;
const changelogPath = path.join(ROOT, "CHANGELOG.md");
if (fs.existsSync(changelogPath)) {
  const top = fs.readFileSync(changelogPath, "utf8").match(/^## \[(?!Unreleased)([^\]]+)\]/im);
  if (!top || top[1] !== version) {
    problem("CHANGELOG.md", `newest entry is ${top ? top[1] : "missing"}, package.json says ${version}`);
  }
}

if (problems.length > 0) {
  console.error(problems.join("\n"));
  console.error(`\n${problems.length} problem(s) found.`);
  process.exit(1);
}
console.log(`OK: ${luaFiles.length} Lua files, ${declared.size} declared globals, version ${version}.`);
