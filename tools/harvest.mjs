// npm run harvest: turns the catch data in saved variables into the bundled seed OneKeyFishing/SeedData.lua
// (specs/002-local-catch-db/contracts/harvest-command.md and seed-data.md).
//   npm run harvest                               every account under WOW_ADDONS_DIR
//   npm run harvest -- friend.lua other.lua       plus saved files friends handed over
//   npm run harvest -- --reset 1415               map 1415 counts only data of the newest game version
//   npm run harvest -- --synthetic 3000           a random seed of 3000 places for a load test (never commit it)
//   npm run harvest -- --block <id> "why"         leave a contribution ID out of the seed (part 3, FR-019);
//   npm run harvest -- --unblock <id>             the seed's `blocked` tells every client to drop it
// Saved files are parsed, never executed. Accepted contributions are kept in seed/contributions.json, keyed by
// "<id>@<epoch>": a newer seq replaces the stored record, so the same input never counts twice, and a run that
// changes no sums leaves SeedData.lua and its epoch as they are.
import crypto from "node:crypto";
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
const PLACE_KEY = /^(\d+):([0-4]):(\d\d|x)$/;
// The version chain and the weights of part 3 (specs/004-public-channel-sync, research R7 and R9), as in CatchDB.lua.
const PROOF = /^[a-z2-7]{16}$/;
const BASE32 = "abcdefghijklmnopqrstuvwxyz234567";
const CHAIN_LENGTH = 4096; // CatchDB.CHAIN_LENGTH: the longest jump between two versions of a unit
const STEP_SECONDS = 180; // CatchDB.STEP_SECONDS: casting per step of a record's seq
const WEIGHT_FROM = 5; // contributors at a cell from which one contribution carries at most WEIGHT_SHARE
const WEIGHT_SHARE = 1 / 5;
const MAX_ITEM_ID = 2147483647;

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

// An own property even for "__proto__", which a plain assignment would take as the object's prototype.
function setField(target, key, value) {
  Object.defineProperty(target, key, { value, enumerable: true, writable: true, configurable: true });
}

// Lua tables become objects; positional entries get the keys 1, 2, ... (so { 64, 71 } is { 1: 64, 2: 71 }).
function luaTable(node) {
  const result = {};
  let position = 0;
  for (const field of node.fields) {
    if (field.type === "TableKeyString") {
      setField(result, field.key.name, luaValue(field.value));
    } else if (field.type === "TableKey") {
      setField(result, String(luaValue(field.key)), luaValue(field.value));
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
  for (const [id, epochs] of Object.entries(seed.proofs || {})) {
    const units = typeof epochs === "object" && epochs !== null ? Object.entries(epochs) : [];
    if (!ID.test(id) || units.length === 0
      || units.some(([epoch, proof]) => !/^\d+$/.test(epoch) || !PROOF.test(String(proof)))) {
      problems.push(`proofs["${id}"] is not { [epoch] = "<16 base32>", ... }`);
    }
  }
  for (const [id, value] of Object.entries(seed.blocked || {})) {
    if (!ID.test(id) || value !== true) {
      problems.push(`blocked["${id}"] is not true`);
    }
  }
  for (const [id, epochs] of Object.entries(seed.absorbed || {})) {
    const units = typeof epochs === "object" && epochs !== null ? Object.entries(epochs) : [];
    if (!ID.test(id) || units.length === 0
      || units.some(([epoch, seq]) => !/^\d+$/.test(epoch) || !Number.isInteger(seq) || seq < 0)) {
      problems.push(`absorbed["${id}"] is not { [epoch] = seq, ... }`);
    }
  }
  return problems;
}

// --- The version chain (specs/004-public-channel-sync, data-model.md "The version chain") ----------------------

// One link down a chain: the first 80 bits of SHA-256 as 16 base32 characters, 5 hex digits to 4 characters
// (ns.ProofStep and ns.HexToBase32 in Data.lua compute the same).
export function proofStep(link) {
  const hex = crypto.createHash("sha256").update(link, "latin1").digest("hex");
  let out = "";
  for (let group = 0; group < 4; group += 1) {
    let value = parseInt(hex.slice(group * 5, group * 5 + 5), 16);
    let chars = "";
    for (let k = 0; k < 4; k += 1) {
      chars = BASE32[value % 32] + chars;
      value = Math.floor(value / 32);
    }
    out += chars;
  }
  return out;
}

// Why a newer version of a unit does not continue the stored one, or null: its proof, stepped down to the stored
// seq, must be the stored proof (only the owner can make it). A stored record without a proof (from before part 3)
// is no anchor.
function chainProblem(stored, record) {
  if (!PROOF.test(stored.proof || "")) {
    return null;
  }
  if (record.seq - stored.seq > CHAIN_LENGTH) {
    return "a jump over a whole chain";
  }
  let link = record.proof;
  for (let i = stored.seq; i < record.seq; i += 1) {
    link = proofStep(link);
  }
  return link === stored.proof ? null : "the proof does not continue the stored version";
}

// True when a version and one at the same or a higher seq cannot both be the owner's: the same seq with another
// proof, or a higher one whose chain does not lead down to the lower one. Which one is made up is unknown; a version
// without a proof (stored before part 3) tells nothing.
function versionsSplit(lower, higher) {
  if (!PROOF.test(lower.proof || "") || !PROOF.test(higher.proof || "")) {
    return false;
  }
  return lower.seq === higher.seq ? lower.proof !== higher.proof : chainProblem(lower, higher) !== null;
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
    if (!/^[1-9]\d*$/.test(itemID) || Number(itemID) > MAX_ITEM_ID) {
      throw new Error(`${where}: item ID ${itemID} is not a positive 32-bit number`);
    }
    const withItem = entry && entry["1"];
    const pieces = entry && entry["2"];
    if (!isCount(withItem) || !isCount(pieces) || withItem > catches || pieces < withItem
      || pieces > MAX_PIECES * withItem) {
      throw new Error(`${where}: item ${itemID} has impossible counts (${withItem} catches, ${pieces} pieces)`);
    }
  }
}

// Only the fields the client reads (as Share.lua's CleanCell rebuilds a received cell), as own properties.
function cleanCell(cell) {
  const items = (source) => Object.fromEntries(Object.entries(source || {})
    .map(([itemID, entry]) => [itemID, { 1: entry["1"], 2: entry["2"] }]));
  const clean = { c: cell.c, m: cell.m, t: cell.t };
  if (cell.px !== undefined) {
    clean.px = cell.px;
    clean.py = cell.py;
  }
  clean.i = items(cell.i);
  if (cell.p !== undefined) {
    clean.p = { c: cell.p.c, i: items(cell.p.i) };
  }
  return clean;
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

// The casts (catches and misses) of every cell of every build whose counts are counts, valid or not otherwise; the
// seconds of casting only under game versions: casts under an unknown build ("unknown" when GetBuildInfo failed)
// never raise the seq (CatchDB.lua), so their seconds would make an honest record cast too long.
function rawCasts(record) {
  let casts = 0;
  let seconds = 0;
  for (const [build, cells] of Object.entries(record.builds || {})) {
    for (const value of Object.values(cells || {})) {
      if (value && isCount(value.c) && isCount(value.m)) {
        casts += value.c + value.m;
        seconds += BUILD.test(build) && isCount(value.t) ? value.t : 0;
      }
    }
  }
  return { casts, seconds };
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
  // The seq grows only after a settled cast (as CatchDB.CheckRecord checks): a higher one is made up, and as the
  // newest seq it would replace the owner's real record here. Counted before odd cells are skipped, so a skipped
  // cell does not reject an honest record.
  const { casts, seconds } = rawCasts(record);
  if (record.seq > casts) {
    throw new Error(`seq ${record.seq} is above the record's ${casts} casts`);
  }
  // Part 3: the owner's proof, and no more casting than STEP_SECONDS per step of the seq (research R9).
  if (!PROOF.test(record.proof || "")) {
    throw new Error("the proof is not 16 base32 characters");
  }
  if (seconds > STEP_SECONDS * record.seq) {
    throw new Error(`more casting than ${record.seq} version steps allow`);
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
      builds[build][key] = cleanCell(cell);
      places.add(key);
    }
  }
  if (places.size > MAX_PLACES_PER_RECORD) {
    throw new Error(`${places.size} places, more than ${MAX_PLACES_PER_RECORD}`);
  }
  return { id: record.id, epoch: record.epoch, seq: record.seq, proof: record.proof, builds };
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

// The weight factor of each contributor at a cell (research R7 of part 3): from WEIGHT_FROM contributors on, the
// largest are capped one by one at T, WEIGHT_SHARE of the weighted total; at most four are capped (the fifth is never
// above the rest).
// totals: contributor ID -> what it is capped by at the cell (catches, or casts for the miss rate). players: the
// contributors who caught something there; as in the views (CatchDB.lua) only they count toward WEIGHT_FROM.
function weightFactors(totals, players) {
  const factors = new Map();
  if (players < WEIGHT_FROM) {
    return factors;
  }
  const list = [...totals.entries()].filter(([, c]) => c > 0)
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
  const shares = 1 / WEIGHT_SHARE;
  let rest = list.reduce((sum, [, c]) => sum + c, 0);
  let cap = rest * WEIGHT_SHARE;
  let capped = 0;
  for (const [, c] of list) {
    if (c <= cap) {
      break;
    }
    capped += 1;
    rest -= c;
    cap = rest / (shares - capped);
  }
  for (const [id, c] of list) {
    if (c > cap) {
      factors.set(id, cap / c);
    }
  }
  return factors;
}

function scaleItems(items, factor, catches) {
  const out = {};
  for (const [itemID, entry] of Object.entries(items || {})) {
    const withItem = Math.min(Math.round(entry["1"] * factor), catches);
    if (withItem > 0) {
      out[itemID] = { 1: withItem, 2: Math.min(Math.max(Math.round(entry["2"] * factor), withItem),
        MAX_PIECES * withItem) };
    }
  }
  return out;
}

// A cell scaled by weight factors (the catches and items by `factor`, the misses by `missFactor`, the one of the
// casts), rounded and still within the cell rules. Positions are summed per cast, so they go with the casts.
function scaleCell(cell, factor, missFactor = factor) {
  const c = Math.round(cell.c * factor);
  const m = Math.round(cell.m * missFactor);
  const scaled = { c, m, t: Math.max(Math.round(cell.t * Math.max(factor, missFactor)), c + m),
    i: scaleItems(cell.i, factor, c) };
  if (cell.px !== undefined) {
    const casts = cell.c + cell.m;
    const ratio = missFactor === factor || casts === 0 ? factor : (c + m) / casts;
    scaled.px = Math.min(Math.round(cell.px * ratio), 1000 * (c + m));
    scaled.py = Math.min(Math.round(cell.py * ratio), 1000 * (c + m));
  }
  if (cell.p) {
    const poolCatches = Math.min(Math.round(cell.p.c * factor), c);
    scaled.p = { c: poolCatches, i: scaleItems(cell.p.i, factor, poolCatches) };
  }
  return scaled;
}

// The stored contributions the author has not blocked (FR-019): only they reach the outlier report.
function unblocked(store) {
  return Object.values(store.contributions).filter((record) => store.blocked[record.id] === undefined);
}

// The stored contributions that reach the seed (its sums, absorbed and proofs): not blocked, and not of a disputed
// unit, whose stored version may be the made-up one (absorbed at its seq would make clients delete the owner's copies,
// its proof would make them refuse the owner's versions and blame whoever relays them).
function included(store) {
  return unblocked(store).filter((record) => store.disputed[`${record.id}@${record.epoch}`] === undefined);
}

function sumContributions(store) {
  const entries = {}; // place key -> { id, cell } of every contribution there (an ID may have several epochs)
  for (const record of included(store)) {
    for (const [build, buildCells] of Object.entries(record.builds)) {
      for (const [key, cell] of Object.entries(buildCells)) {
        const mapID = key.match(PLACE_KEY)[1];
        const reset = store.resets[mapID];
        if (reset && compareBuilds(build, reset) < 0) {
          continue;
        }
        (entries[key] = entries[key] || []).push({ id: record.id, cell });
      }
    }
  }
  const cells = {};
  for (const [key, list] of Object.entries(entries)) {
    const totals = new Map();
    const casts = new Map();
    for (const { id, cell } of list) {
      totals.set(id, (totals.get(id) || 0) + cell.c);
      casts.set(id, (casts.get(id) || 0) + cell.c + cell.m);
    }
    const players = [...totals.values()].filter((c) => c > 0).length;
    const factors = weightFactors(totals, players);
    const castFactors = weightFactors(casts, players);
    // k: the contributors who caught something there, as the views count players (CatchDB.lua).
    const sum = { c: 0, m: 0, t: 0, k: players, i: {} };
    let castCatches = 0; // the catches weighted by casts
    let rawCatches = 0;
    for (const { id, cell: original } of list) {
      const factor = factors.has(id) ? factors.get(id) : 1;
      const castFactor = castFactors.has(id) ? castFactors.get(id) : 1;
      const cell = factor !== 1 || castFactor !== 1 ? scaleCell(original, factor, castFactor) : original;
      // The same factor for both: the rounded catches, so x appears only where the cast weighting differs.
      castCatches += castFactor === factor ? cell.c : original.c * castFactor;
      rawCatches += original.c;
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
    }
    // The catches weighted by casts, when they differ from those weighted by catches: the views take the miss rate
    // from x + m (CatchDB.lua), so it is the one weighted by casts, while c gives the chances.
    if (Math.round(castCatches) !== sum.c) {
      sum.x = Math.round(castCatches);
      sum.t = Math.max(sum.t, sum.x + sum.m);
    }
    // The raw catches, when the weights changed them: the views' little-data threshold and catch count read them.
    if (rawCatches !== sum.c) {
      sum.r = rawCatches;
    }
    cells[key] = sum;
  }
  return cells;
}

// --- The outlier report (part 3, research R11) ----------------------------------------------------------------
// Contributions whose numbers look odd next to the others at the same places. The author judges; the thresholds
// only point at what to look at.
const FAST_CAST_SECONDS = 3; // casting faster than this per cast on average is not fishing
const FAST_MIN_CASTS = 50;
const SHARE_REST_CATCHES = 100; // the others' catches a cell needs before its item shares are compared
const SHARE_OWN_CATCHES = 50; // the contribution's own catches at that cell
const SHARE_DISTANCE = 0.5; // total variation between the two item shares
const SHARE_MIN_CELLS = 3;
const PIECES_FACTOR = 3; // pieces per catch of an item this many times the others'
const PIECES_MIN_CATCHES = 20;

// Item ID -> share of the item catches in a list of item tables.
function itemShares(itemTables) {
  const counts = {};
  let total = 0;
  for (const items of itemTables) {
    for (const [itemID, entry] of Object.entries(items || {})) {
      counts[itemID] = (counts[itemID] || 0) + entry["1"];
      total += entry["1"];
    }
  }
  return { counts, total };
}

function outlierReport(store, oldItems) {
  const records = unblocked(store);
  const byKey = {}; // place key -> [{ record, cell }]
  const itemOwners = {}; // item ID -> Set of contribution IDs
  for (const record of records) {
    for (const buildCells of Object.values(record.builds)) {
      for (const [key, cell] of Object.entries(buildCells)) {
        (byKey[key] = byKey[key] || []).push({ record, cell });
        for (const itemID of Object.keys(cell.i || {})) {
          (itemOwners[itemID] = itemOwners[itemID] || new Set()).add(record.id);
        }
      }
    }
  }
  const lines = [];
  for (const record of records) {
    const reasons = [];
    let odd = 0;
    let pieces = false;
    const lonely = new Set();
    for (const buildCells of Object.values(record.builds)) {
      for (const [key, cell] of Object.entries(buildCells)) {
        const others = byKey[key].filter((entry) => entry.record !== record);
        const rest = others.reduce((sum, entry) => sum + entry.cell.c, 0);
        if (rest >= SHARE_REST_CATCHES && cell.c >= SHARE_OWN_CATCHES) {
          const mine = itemShares([cell.i]);
          const theirs = itemShares(others.map((entry) => entry.cell.i));
          const ids = new Set([...Object.keys(mine.counts), ...Object.keys(theirs.counts)]);
          let distance = 0;
          for (const itemID of ids) {
            distance += Math.abs((mine.counts[itemID] || 0) / (mine.total || 1)
              - (theirs.counts[itemID] || 0) / (theirs.total || 1));
          }
          if (distance / 2 >= SHARE_DISTANCE) {
            odd += 1;
          }
        }
        for (const [itemID, entry] of Object.entries(cell.i || {})) {
          // Only where the others fished too: a lone item of a place nobody else fished is just new data.
          if (itemOwners[itemID].size === 1 && !oldItems.has(itemID) && rest >= SHARE_REST_CATCHES) {
            lonely.add(itemID);
          }
          const otherEntries = others.map((e) => e.cell.i && e.cell.i[itemID]).filter(Boolean);
          const otherCatches = otherEntries.reduce((sum, e) => sum + e["1"], 0);
          const otherPieces = otherEntries.reduce((sum, e) => sum + e["2"], 0);
          if (entry["1"] >= PIECES_MIN_CATCHES && otherCatches >= PIECES_MIN_CATCHES
            && entry["2"] / entry["1"] >= PIECES_FACTOR * (otherPieces / otherCatches)) {
            pieces = true;
          }
        }
      }
    }
    const { casts, seconds } = rawCasts(record);
    if (casts >= FAST_MIN_CASTS && seconds / casts < FAST_CAST_SECONDS) {
      reasons.push(`casts every ${(seconds / casts).toFixed(1)} s on average`);
    }
    if (odd >= SHARE_MIN_CELLS) {
      reasons.push(`item shares unlike the others' at ${odd} cells`);
    }
    if (lonely.size > 0) {
      reasons.push(`items nobody else reports: ${[...lonely].sort(byNumber).join(", ")}`);
    }
    if (pieces) {
      reasons.push(`pieces per catch ${PIECES_FACTOR} times the others'`);
    }
    if (reasons.length > 0) {
      lines.push(`  outlier   ${record.id}@${record.epoch}: ${reasons.join("; ")}`);
    }
  }
  if (lines.length > 0) {
    lines.push('  block one with: npm run harvest -- --block <id> "why"');
  }
  return lines;
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
  if (cell.x !== undefined) {
    head.push(`x = ${cell.x}`);
  }
  if (cell.r !== undefined) {
    head.push(`r = ${cell.r}`);
  }
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
    ...block("absorbed", Object.keys(seed.absorbed).sort().flatMap((id) => wrap(`    ["${id}"] = {`,
      Object.keys(seed.absorbed[id]).sort(byNumber).map((epoch) => `[${epoch}] = ${seed.absorbed[id][epoch]}`),
      "      ", " },"))),
    ...block("proofs", Object.keys(seed.proofs || {}).sort().flatMap((id) => wrap(`    ["${id}"] = {`,
      Object.keys(seed.proofs[id]).sort(byNumber).map((epoch) => `[${epoch}] = "${seed.proofs[id][epoch]}"`),
      "      ", " },"))),
    ...block("blocked", Object.keys(seed.blocked || {}).sort().map((id) => `    ["${id}"] = true,`)),
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
    return { epoch: 0, resets: {}, contributions: {}, blocked: {}, disputed: {} };
  }
  const store = JSON.parse(fs.readFileSync(file, "utf8"));
  return { epoch: store.epoch || 0, resets: store.resets || {}, contributions: store.contributions || {},
    blocked: store.blocked || {}, disputed: store.disputed || {} };
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
  const previousText = fs.existsSync(seedFile) ? fs.readFileSync(seedFile, "utf8") : null;
  const previous = previousText && parseSeed(previousText);
  const files = [...accountFiles(options.addonsDir),
    ...(options.files || []).map((file) => ({ file, name: path.basename(file) }))];
  const notes = [];
  const units = new Set(); // every <id>@<epoch> accepted from the input, however often it came
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
    // The own record (keyed by its ID) and other players' records the client received (keyed by <id>@<epoch>,
    // with a local `seen`): neither the key nor seen matters, checkRecord rebuilds { id, epoch, seq, builds }.
    for (const [key, record] of Object.entries(db?.shared?.records || {})) {
      read += 1;
      try {
        const clean = checkRecord(record, notes);
        const storeKey = `${clean.id}@${clean.epoch}`;
        const stored = store.contributions[storeKey];
        if (!stored || clean.seq > stored.seq) {
          const problem = stored && chainProblem(stored, clean);
          if (problem) {
            store.disputed[storeKey] = name; // not on one chain: either may be made up, the stored one too
            throw new Error(problem);
          }
          store.contributions[storeKey] = clean;
        } else if (versionsSplit(clean, stored)) {
          store.disputed[storeKey] = name;
        }
        units.add(storeKey);
      } catch (error) {
        rejected += 1;
        notes.push(`  rejected  ${name} ${String(key).slice(0, 4)}...: ${error.message}`);
      }
    }
  }

  const resetNotes = [];
  for (const { id, note } of [].concat(options.block || [])) {
    if (!ID.test(String(id))) {
      return { ok: false, report: [`error: --block needs a contribution ID (8 base32 characters), got "${id}"`] };
    }
    store.blocked[id] = note || "";
    resetNotes.push(`Blocked: ${id}${note ? ` (${note})` : ""}`);
  }
  for (const id of [].concat(options.unblock || [])) {
    if (store.blocked[id] === undefined) {
      return { ok: false, report: [`error: --unblock ${id}: it is not blocked`] };
    }
    delete store.blocked[id];
    resetNotes.push(`Unblocked: ${id}`);
  }
  // The newest game version among the contributions that reach the seed: a blocked or disputed one (maybe made up,
  // with any version number) must not decide the seed's build or where a --reset cuts a map off.
  let newest = null;
  for (const record of included(store)) {
    for (const build of Object.keys(record.builds)) {
      if (!newest || compareBuilds(build, newest) > 0) {
        newest = build;
      }
    }
  }
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
  // Every unit summed, with the seq summed: a client keeps a newer seq of it (the rest goes to the next harvest),
  // and deletes the versions up to it.
  const absorbed = {};
  const proofs = {}; // the proof of every absorbed version: a newer one must continue it (research R9 of part 3)
  for (const record of included(store)) {
    absorbed[record.id] = { ...absorbed[record.id], [record.epoch]: record.seq };
    if (PROOF.test(record.proof || "")) {
      proofs[record.id] = { ...proofs[record.id], [record.epoch]: record.proof };
    }
  }
  // The epoch only grows, also when the contributions file was lost while the shipped seed is newer: an epoch that
  // repeated or went back would let clients count their own record next to a seed that already holds it.
  const baseEpoch = Math.max(store.epoch, Number.isInteger(previous?.epoch) ? previous.epoch : 0);
  const seed = { epoch: baseEpoch + 1, built: now.toISOString().slice(0, 10), build: newest || "", absorbed,
    proofs, blocked: Object.fromEntries(Object.keys(store.blocked).map((id) => [id, true])), resets: store.resets,
    cells };
  const text = seedText(seed);
  const bytes = Buffer.byteLength(text);
  // The same seed as the current file (apart from its epoch and date): nothing to release.
  const unchanged = previous && seedText({ ...seed, epoch: previous.epoch, built: previous.built }) === previousText;

  const oldCells = previous?.cells || {};
  const oldItems = new Set(Object.values(oldCells).flatMap((cell) => Object.keys(cell.i || {})));
  const newPlaces = Object.keys(cells).filter((key) => !(key in oldCells)).length;
  const newItems = new Set(Object.values(cells).flatMap((cell) => Object.keys(cell.i))
    .filter((id) => !oldItems.has(id))).size;
  report.push(`Harvest: ${files.length} file(s), ${read} record(s) read, ${rejected} rejected`);
  report.push(...notes);
  for (const unit of Object.keys(store.disputed).sort()) {
    report.push(`Disputed: ${unit}: versions that are not on one chain (one is made up); left out of the seed, `
      + "since the version stored may be the made-up one (the owner's next epoch is a new unit)");
  }
  report.push(`Contributions: ${units.size} (each <id>@<epoch> once, its newest seq)`);
  report.push(`New places: ${newPlaces}   New items: ${newItems}   Places in total: ${Object.keys(cells).length}`);
  report.push(...resetNotes);
  report.push(...outlierReport(store, oldItems));
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

// The command line as harvest() options ({ files, reset, block, unblock, synthetic }), or { error }.
export function parseArgs(argv) {
  const files = [];
  const reset = [];
  const block = [];
  const unblock = [];
  let synthetic;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--reset") {
      reset.push(argv[++i]);
    } else if (argv[i] === "--block") {
      const id = argv[++i];
      // The note is the next argument unless it is an option or a saved file (one that exists, or a .lua name).
      const next = argv[i + 1];
      const file = next !== undefined && (next.toLowerCase().endsWith(".lua")
        || (fs.existsSync(next) && fs.statSync(next).isFile()));
      const note = next !== undefined && !next.startsWith("--") && !file ? argv[++i] : "";
      block.push({ id, note });
    } else if (argv[i] === "--unblock") {
      unblock.push(argv[++i]);
    } else if (argv[i] === "--synthetic") {
      synthetic = Number(argv[++i]);
      if (!Number.isInteger(synthetic) || synthetic <= 0) {
        return { error: "error: --synthetic needs a number of places" };
      }
    } else {
      files.push(path.resolve(argv[i]));
    }
  }
  return { files, reset, block, unblock, synthetic };
}

function main(argv) {
  const args = parseArgs(argv);
  if (args.error) {
    console.error(args.error);
    return 1;
  }
  const { files, reset, block, unblock, synthetic } = args;
  // The accounts come from WOW_ADDONS_DIR; with friends' files only, it may be left unset.
  const dir = synthetic ? null : addonsDir({ optional: files.length > 0 });
  const result = harvest({ addonsDir: dir, files, reset, block, unblock, synthetic });
  for (const line of result.report) {
    (line.startsWith("error") ? console.error : console.log)(line);
  }
  return result.ok ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  process.exitCode = main(process.argv.slice(2));
}
