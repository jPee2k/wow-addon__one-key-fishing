// npm run harvest: turns the catch data in saved variables into the bundled seed OneKeyFishing/SeedData.lua
// (specs/002-local-catch-db/contracts/harvest-command.md and seed-data.md).
//   npm run harvest                               every account under WOW_ADDONS_DIR
//   npm run harvest -- friend.lua other.lua       plus saved files friends handed over
//   npm run harvest -- --reset 1415               map 1415 counts only data of the newest game version
//   npm run harvest -- --synthetic 3000           a random seed of 3000 places for a load test (never commit it)
// Saved files are parsed, never executed. Accepted contributions are kept in seed/contributions.json, keyed by
// "<id>@<epoch>": a newer seq replaces the stored record, so the same input never counts twice, and a run that
// changes no sums leaves SeedData.lua and its epoch as they are.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import luaparse from "luaparse";
import { ADDON, MAX_LINE_LENGTH as MAX_LINE, ROOT, addonsDir } from "./addon.mjs";

export const MAX_SEED_BYTES = 1024 * 1024;
// Distinct places per record, against garbage only: the whole world is a few thousand places per skill range,
// and a real account only grows, so a cap a real player can reach would keep that account out for good.
const MAX_PLACES_PER_RECORD = 20000;
const MAX_PIECES = 20;
const ID = /^[a-z2-7]{8}$/;
const BUILD = /^\d+\.\d+\.\d+$/;
export const PLACE_KEY = /^(\d+):([0-4]):(\d\d|x)$/;

// --- Reading Lua tables (luaparse AST -> plain JS values) ------------------------------------------------------

function luaValue(node) {
  switch (node.type) {
    case "StringLiteral":
      // Without an encodingMode (npm run check parses so) luaparse gives no value; the seed's strings are plain.
      return node.value ?? node.raw.slice(1, -1);
    case "NumericLiteral":
      return node.value;
    case "BooleanLiteral":
      return node.value;
    case "NilLiteral":
      return null;
    case "UnaryExpression":
      if (node.operator === "-" && node.argument.type === "NumericLiteral") {
        return -node.argument.value;
      }
      break;
    case "TableConstructorExpression":
      return luaTable(node);
    default:
      break;
  }
  throw new Error(`unsupported value (${node.type})`);
}

// Lua tables become objects; positional entries get the keys 1, 2, ... (so { 64, 71 } is { 1: 64, 2: 71 }).
function luaTable(node) {
  const result = {};
  let position = 0;
  for (const field of node.fields) {
    if (field.type === "TableKeyString") {
      result[field.key.name] = luaValue(field.value);
    } else if (field.type === "TableKey") {
      result[String(luaValue(field.key))] = luaValue(field.value);
    } else {
      position += 1;
      result[String(position)] = luaValue(field.value);
    }
  }
  return result;
}

function parseLua(text) {
  return luaparse.parse(text, { luaVersion: "5.1", encodingMode: "pseudo-latin1", comments: false });
}

// The table assigned to a global (OneKeyFishingDB = {...}) or a field (ns.SeedData = {...}), or null.
function assignedTable(ast, matches) {
  for (const node of ast.body) {
    if (node.type === "AssignmentStatement" && matches(node.variables[0])
      && node.init[0] && node.init[0].type === "TableConstructorExpression") {
      return luaTable(node.init[0]);
    }
  }
  return null;
}

function readSavedVariables(file) {
  const ast = parseLua(fs.readFileSync(file, "latin1"));
  return assignedTable(ast, (v) => v.type === "Identifier" && v.name === "OneKeyFishingDB");
}

const seedTable = (ast) => assignedTable(ast, (v) => v.type === "MemberExpression" && v.base.name === "ns"
  && v.identifier.name === "SeedData");

// The seed in the text of a SeedData.lua file as plain values, or null.
export function parseSeed(text) {
  return seedTable(parseLua(text));
}

function readSeed(file) {
  return fs.existsSync(file) ? parseSeed(fs.readFileSync(file, "utf8")) : null;
}

// What is wrong with a parsed SeedData.lua (contracts/seed-data.md), for npm run check.
export function seedProblems(ast) {
  const seed = seedTable(ast);
  if (!seed) {
    return ["does not assign a table to ns.SeedData"];
  }
  const problems = [];
  const types = { epoch: "number", built: "string", build: "string", absorbed: "object", resets: "object",
    cells: "object" };
  for (const [name, type] of Object.entries(types)) {
    if (typeof seed[name] !== type || seed[name] === null) {
      problems.push(`ns.SeedData.${name} is missing or not a ${type === "object" ? "table" : type}`);
    }
  }
  for (const key of Object.keys(seed.cells || {})) {
    if (!PLACE_KEY.test(key)) {
      problems.push(`cell key "${key}" is not "<mapID>:<range>:<cell>"`);
    }
  }
  return problems;
}

// --- Validation (data-model.md "Validation") -------------------------------------------------------------------

const isCount = (value) => Number.isInteger(value) && value >= 0;

function checkItems(items, catches, where) {
  if (items === undefined) {
    return;
  }
  if (typeof items !== "object" || items === null) {
    throw new Error(`${where}: items are not a table`);
  }
  for (const [itemID, entry] of Object.entries(items)) {
    if (!/^[1-9]\d*$/.test(itemID)) {
      throw new Error(`${where}: item ID ${itemID} is not a positive number`);
    }
    const withItem = entry && entry["1"];
    const pieces = entry && entry["2"];
    if (!isCount(withItem) || !isCount(pieces) || withItem > catches || pieces < withItem
      || pieces > MAX_PIECES * withItem) {
      throw new Error(`${where}: item ${itemID} has impossible counts (${withItem} catches, ${pieces} pieces)`);
    }
  }
}

function checkCell(cell, key) {
  const where = `cell ${key}`;
  if (typeof cell !== "object" || cell === null) {
    throw new Error(`${where}: not a table`);
  }
  for (const name of ["c", "m", "t"]) {
    if (!isCount(cell[name])) {
      throw new Error(`${where}: ${name} is not a count`);
    }
  }
  const casts = cell.c + cell.m;
  if (casts > cell.t) {
    throw new Error(`${where}: ${casts} casts in ${cell.t} s of casting`);
  }
  if ((cell.px === undefined) !== (cell.py === undefined)) {
    throw new Error(`${where}: px and py come together`);
  }
  for (const name of ["px", "py"]) {
    if (cell[name] !== undefined && !(isCount(cell[name]) && cell[name] <= 1000 * casts)) {
      throw new Error(`${where}: ${name} is out of range`);
    }
  }
  checkItems(cell.i, cell.c, where);
  if (cell.p !== undefined) {
    const pool = cell.p;
    if (typeof pool !== "object" || !isCount(pool.c) || pool.c > cell.c) {
      throw new Error(`${where}: the pool part does not fit the totals`);
    }
    checkItems(pool.i, pool.c, `${where} (pool)`);
  }
}

// Returns the record cleaned to { id, epoch, seq, builds }; throws with the reason when it must be rejected.
function checkRecord(record, notes) {
  if (typeof record !== "object" || record === null) {
    throw new Error("not a table");
  }
  if (typeof record.id !== "string" || !ID.test(record.id)) {
    throw new Error("the ID is not 8 base32 characters");
  }
  if (!isCount(record.epoch) || !isCount(record.seq)) {
    throw new Error("epoch or seq is not a count");
  }
  const builds = {};
  const places = new Set();
  for (const [build, cells] of Object.entries(record.builds || {})) {
    if (!BUILD.test(build)) {
      notes.push(`  skipped   ${record.id} build "${build}" (not a game version)`);
      continue;
    }
    builds[build] = {};
    for (const [key, cell] of Object.entries(cells || {})) {
      // One odd cell leaves out that cell, not the record: cells only grow, so the record would stay rejected.
      try {
        if (!PLACE_KEY.test(key)) {
          throw new Error(`place key "${key}" is not "<mapID>:<range>:<cell>"`);
        }
        checkCell(cell, key);
      } catch (error) {
        notes.push(`  skipped   ${record.id} ${error.message}`);
        continue;
      }
      builds[build][key] = cell;
      places.add(key);
    }
  }
  if (places.size > MAX_PLACES_PER_RECORD) {
    throw new Error(`${places.size} places, more than ${MAX_PLACES_PER_RECORD}`);
  }
  return { id: record.id, epoch: record.epoch, seq: record.seq, builds };
}

// --- Sums ------------------------------------------------------------------------------------------------------

function compareBuilds(a, b) {
  const x = a.split(".").map(Number);
  const y = b.split(".").map(Number);
  for (let i = 0; i < 3; i += 1) {
    if (x[i] !== y[i]) {
      return x[i] - y[i];
    }
  }
  return 0;
}

function addItems(target, items) {
  for (const [itemID, entry] of Object.entries(items || {})) {
    const total = target[itemID] || [0, 0];
    total[0] += entry["1"];
    total[1] += entry["2"];
    target[itemID] = total;
  }
}

function sumContributions(store) {
  const cells = {};
  const contributors = {}; // place key -> the IDs that fished there (an ID may have records of several epochs)
  for (const record of Object.values(store.contributions)) {
    for (const [build, buildCells] of Object.entries(record.builds)) {
      for (const [key, cell] of Object.entries(buildCells)) {
        const mapID = key.match(PLACE_KEY)[1];
        const reset = store.resets[mapID];
        if (reset && compareBuilds(build, reset) < 0) {
          continue;
        }
        const sum = cells[key] || { c: 0, m: 0, t: 0, k: 0, i: {} };
        sum.c += cell.c;
        sum.m += cell.m;
        sum.t += cell.t;
        if (cell.px !== undefined) {
          sum.px = (sum.px || 0) + cell.px;
          sum.py = (sum.py || 0) + cell.py;
        }
        addItems(sum.i, cell.i);
        if (cell.p) {
          sum.p = sum.p || { c: 0, i: {} };
          sum.p.c += cell.p.c;
          addItems(sum.p.i, cell.p.i);
        }
        contributors[key] = contributors[key] || new Set();
        contributors[key].add(record.id);
        sum.k = contributors[key].size;
        cells[key] = sum;
      }
    }
  }
  return cells;
}

// --- Writing SeedData.lua --------------------------------------------------------------------------------------

const byNumber = (a, b) => Number(a) - Number(b);

// `open part, part, ... part close` on lines of at most MAX_LINE characters; continuation lines start with
// `indent`. Without parts: `open close` with "{ }" written as "{}".
function wrap(open, parts, indent, close) {
  if (parts.length === 0) {
    return [`${open}${close}`.replace("{ }", "{}")];
  }
  const lines = [];
  let line = open;
  parts.forEach((part, index) => {
    const token = index < parts.length - 1 ? `${part},` : part;
    if (line !== open && line !== indent && `${line} ${token}`.length > MAX_LINE) {
      lines.push(line);
      line = indent + token;
    } else {
      line = line === indent ? indent + token : `${line} ${token}`;
    }
  });
  if (`${line}${close}`.length > MAX_LINE) {
    lines.push(line);
    line = indent + close.trim();
  } else {
    line += close;
  }
  lines.push(line);
  return lines;
}

function itemParts(items) {
  return Object.keys(items).sort(byNumber).map((id) => `[${id}] = { ${items[id][0]}, ${items[id][1]} }`);
}

function cellLines(key, cell) {
  const head = [`c = ${cell.c}`, `m = ${cell.m}`, `t = ${cell.t}`];
  if (cell.px !== undefined) {
    head.push(`px = ${cell.px}`, `py = ${cell.py}`);
  }
  head.push(`k = ${cell.k}`);
  const lines = [`    ["${key}"] = { ${head.join(", ")},`];
  const items = itemParts(cell.i);
  if (cell.p) {
    lines.push(...wrap("      i = {", items, "        ", " },"));
    lines.push(...wrap(`      p = { c = ${cell.p.c}, i = {`, itemParts(cell.p.i), "        ",
      " } } },"));
  } else {
    lines.push(...wrap("      i = {", items, "        ", " } },"));
  }
  return lines;
}

// A field of the seed table with one entry per line, or `name = {},` when it is empty.
function block(name, entries) {
  return entries.length > 0 ? [`  ${name} = {`, ...entries, "  },"] : [`  ${name} = {},`];
}

function seedText(seed) {
  const lines = [
    "-- Generated by npm run harvest; do not edit.",
    "local _, ns = ...",
    "ns.SeedData = {",
    `  epoch = ${seed.epoch},`,
    `  built = "${seed.built}",`,
    `  build = "${seed.build}",`,
    ...block("absorbed", Object.keys(seed.absorbed).sort().map((id) => `    ["${id}"] = ${seed.absorbed[id]},`)),
    ...block("resets", Object.keys(seed.resets).sort(byNumber)
      .map((mapID) => `    [${mapID}] = "${seed.resets[mapID]}",`)),
    "  cells = {",
  ];
  for (const key of Object.keys(seed.cells).sort()) {
    lines.push(...cellLines(key, seed.cells[key]));
  }
  lines.push("  },", "}", "");
  return lines.join("\n");
}

// --- The harvest -----------------------------------------------------------------------------------------------

function accountFiles(dir) {
  if (!dir) {
    return [];
  }
  const accounts = path.resolve(dir, "..", "..", "WTF", "Account");
  if (!fs.existsSync(accounts)) {
    return [];
  }
  return fs.readdirSync(accounts)
    .map((account) => ({ file: path.join(accounts, account, "SavedVariables", "OneKeyFishing.lua"),
      name: `account ${account}` }))
    .filter(({ file }) => fs.existsSync(file));
}

function loadStore(file) {
  if (!fs.existsSync(file)) {
    return { epoch: 0, resets: {}, contributions: {} };
  }
  const store = JSON.parse(fs.readFileSync(file, "utf8"));
  return { epoch: store.epoch || 0, resets: store.resets || {}, contributions: store.contributions || {} };
}

// The two files a harvest writes, inside the output folder (the repository by default).
const outputFiles = (outDir) => ({ seedFile: path.join(outDir, ADDON, "SeedData.lua"),
  storeFile: path.join(outDir, "seed", "contributions.json") });

function writeFile(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

const kb = (bytes) => `${Math.ceil(bytes / 1024)} KB`;

// options: { addonsDir, files, reset, outDir, synthetic, now }; returns { ok, report, bytes }.
export function harvest(options = {}) {
  const outDir = options.outDir || ROOT;
  const now = options.now || new Date();
  const report = [];
  if (options.synthetic) {
    const seed = syntheticSeed(options.synthetic, now);
    const text = seedText(seed);
    writeFile(outputFiles(outDir).seedFile, text);
    report.push(`Wrote ${ADDON}/SeedData.lua: synthetic seed of ${Object.keys(seed.cells).length} places, `
      + `${kb(Buffer.byteLength(text))}`);
    report.push(`synthetic seed: do not commit, restore with git checkout ${ADDON}/SeedData.lua`);
    return { ok: true, report, bytes: Buffer.byteLength(text) };
  }

  const { seedFile, storeFile } = outputFiles(outDir);
  const store = loadStore(storeFile);
  const previous = readSeed(seedFile);
  const files = [...accountFiles(options.addonsDir),
    ...(options.files || []).map((file) => ({ file, name: path.basename(file) }))];
  const notes = [];
  let read = 0;
  let rejected = 0;
  for (const { file, name } of files) {
    let db;
    try {
      db = readSavedVariables(file);
    } catch (error) {
      rejected += 1;
      notes.push(`  rejected  ${name}: does not parse (${error.message})`);
      continue;
    }
    for (const [key, record] of Object.entries(db?.shared?.records || {})) {
      read += 1;
      try {
        const clean = checkRecord(record, notes);
        const storeKey = `${clean.id}@${clean.epoch}`;
        const stored = store.contributions[storeKey];
        if (!stored || clean.seq > stored.seq) {
          store.contributions[storeKey] = clean;
        }
      } catch (error) {
        rejected += 1;
        notes.push(`  rejected  ${name} ${String(key).slice(0, 4)}...: ${error.message}`);
      }
    }
  }

  let newest = null;
  for (const record of Object.values(store.contributions)) {
    for (const build of Object.keys(record.builds)) {
      if (!newest || compareBuilds(build, newest) > 0) {
        newest = build;
      }
    }
  }
  const resetNotes = [];
  for (const mapID of [].concat(options.reset || [])) {
    if (!/^\d+$/.test(String(mapID))) {
      return { ok: false, report: [`error: --reset needs a map ID, got "${mapID}"`] };
    }
    if (!newest) {
      return { ok: false, report: [`error: --reset ${mapID}: no contributions with a game version yet`] };
    }
    store.resets[String(mapID)] = newest;
    resetNotes.push(`Reset: map ${mapID} (data before ${newest} left out)`);
  }

  const cells = sumContributions(store);
  const absorbed = {};
  for (const record of Object.values(store.contributions)) {
    absorbed[record.id] = Math.max(absorbed[record.id] ?? 0, record.epoch);
  }
  // The epoch only grows, also when the contributions file was lost while the shipped seed is newer: an epoch that
  // repeated or went back would let clients count their own record next to a seed that already holds it.
  const baseEpoch = Math.max(store.epoch, Number.isInteger(previous?.epoch) ? previous.epoch : 0);
  const seed = { epoch: baseEpoch + 1, built: now.toISOString().slice(0, 10), build: newest || "", absorbed,
    resets: store.resets, cells };
  const text = seedText(seed);
  const bytes = Buffer.byteLength(text);
  // The same seed as the current file (apart from its epoch and date): nothing to release.
  const unchanged = previous && fs.existsSync(seedFile)
    && seedText({ ...seed, epoch: previous.epoch, built: previous.built }) === fs.readFileSync(seedFile, "utf8");

  const oldCells = previous?.cells || {};
  const oldItems = new Set(Object.values(oldCells).flatMap((cell) => Object.keys(cell.i || {})));
  const newPlaces = Object.keys(cells).filter((key) => !(key in oldCells)).length;
  const newItems = new Set(Object.values(cells).flatMap((cell) => Object.keys(cell.i))
    .filter((id) => !oldItems.has(id))).size;
  report.push(`Harvest: ${files.length} file(s), ${read} record(s) read, ${rejected} rejected`);
  report.push(...notes);
  report.push(`New places: ${newPlaces}   New items: ${newItems}   Places in total: ${Object.keys(cells).length}`);
  report.push(...resetNotes);
  if (bytes > MAX_SEED_BYTES) {
    report.push(`error: the seed would be ${kb(bytes)}, more than the 1 MB limit; nothing was written`);
    return { ok: false, report, bytes };
  }
  if (unchanged) {
    writeFile(storeFile, `${JSON.stringify(store, null, 1)}\n`); // newer seqs with the same sums
    report.push(`Nothing new: ${ADDON}/SeedData.lua stays at epoch ${previous.epoch}`);
    return { ok: true, report, bytes };
  }
  store.epoch = seed.epoch;
  writeFile(seedFile, text);
  writeFile(storeFile, `${JSON.stringify(store, null, 1)}\n`);
  report.push(`Wrote ${ADDON}/SeedData.lua: epoch ${seed.epoch}, ${kb(bytes)}`);
  return { ok: true, report, bytes };
}

// --- A random seed for the load test (V8) ----------------------------------------------------------------------

function syntheticSeed(places, now) {
  let state = 12345;
  const random = (n) => {
    state = (state * 1103515245 + 12345) % 2147483648;
    return state % n;
  };
  const cells = {};
  for (let index = 0; index < places; index += 1) {
    const mapID = 1400 + Math.floor(index / 10);
    const key = `${mapID}:${random(5)}:${random(10)}${random(10)}`;
    const c = 50 + random(2000);
    const m = random(200);
    const items = {};
    let left = c;
    for (let n = 3 + random(6); n > 0 && left > 0; n -= 1) {
      const withItem = n === 1 ? left : 1 + random(left);
      items[6000 + random(900)] = [withItem, withItem + random(withItem)];
      left -= withItem;
    }
    cells[key] = { c, m, t: (c + m) * 12, px: (c + m) * random(1000), py: (c + m) * random(1000), k: 1 + random(20),
      i: items };
  }
  return { epoch: 0, built: now.toISOString().slice(0, 10), build: "1.60.1", absorbed: {}, resets: {}, cells };
}

// --- Command line ----------------------------------------------------------------------------------------------

function main(argv) {
  const files = [];
  const reset = [];
  let synthetic;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--reset") {
      reset.push(argv[++i]);
    } else if (argv[i] === "--synthetic") {
      synthetic = Number(argv[++i]);
      if (!Number.isInteger(synthetic) || synthetic <= 0) {
        console.error("error: --synthetic needs a number of places");
        return 1;
      }
    } else {
      files.push(path.resolve(argv[i]));
    }
  }
  // The accounts come from WOW_ADDONS_DIR; with friends' files only, it may be left unset.
  const dir = synthetic ? null : addonsDir({ optional: files.length > 0 });
  const result = harvest({ addonsDir: dir, files, reset, synthetic });
  for (const line of result.report) {
    (line.startsWith("error") ? console.error : console.log)(line);
  }
  return result.ok ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  process.exitCode = main(process.argv.slice(2));
}
