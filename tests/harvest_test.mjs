// tools/harvest.mjs: saved files in a temporary game tree -> seed/contributions.json and OneKeyFishing/SeedData.lua
// in a temporary output folder. Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";
import luaparse from "luaparse";
import { harvest, parseArgs, parseSeed, proofStep, seedProblems } from "../tools/harvest.mjs";

// A JS value as Lua source, the way the game writes saved variables (string and number keys in brackets).
function toLua(value) {
  if (value === null || value === undefined) {
    return "nil";
  }
  if (typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value !== "object") {
    return String(value);
  }
  if (Array.isArray(value)) {
    return `{ ${value.map(toLua).join(", ")} }`;
  }
  const fields = Object.entries(value).map(([key, field]) =>
    `[${/^\d+$/.test(key) ? key : JSON.stringify(key)}] = ${toLua(field)}`);
  return `{\n${fields.join(",\n")}\n}`;
}

function savedFile(records) {
  const db = { schema: 2, shared: { myID: Object.keys(records)[0] || "", mine: {}, records } };
  return `OneKeyFishingDB = ${toLua(db)}\nOneKeyFishingCharDB = nil\n`;
}

const cell = (c, m, items, extra = {}) => ({ c, m, t: (c + m) * 10, i: items, ...extra });
// Link `seq` of a version chain of 4096 links made from `secret` (specs/004-public-channel-sync, data-model.md "The
// version chain"): link 4096 is proofStep(secret), every lower link the step of the one above.
const chains = new Map();
function proofFor(secret, seq) {
  if (!chains.has(secret)) {
    const chain = [];
    chain[4096] = proofStep(secret);
    for (let i = 4095; i >= 0; i -= 1) {
      chain[i] = proofStep(chain[i + 1]);
    }
    chains.set(secret, chain);
  }
  return chains.get(secret)[seq];
}
// A record whose proof is its owner's (the secret is its ID).
const record = (id, epoch, seq, builds) => ({ id, epoch, seq, proof: proofFor(id, seq), builds });
// A record with one cell under game version 1.60.1.
const oneCell = (id, epoch, seq, key, value) => record(id, epoch, seq, { "1.60.1": { [key]: value } });

const A = "aaaaaaaa";
const B = "bbbbbbbb";
const F = "ffffffff";
const BAD = "xxxxxxx2";

// A game tree with two accounts, plus a friend's file (one good record, one with impossible numbers) and a file
// that is not Lua at all.
function setup() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-"));
  const addonsDir = path.join(root, "Game", "Interface", "AddOns");
  fs.mkdirSync(addonsDir, { recursive: true });
  const write = (file, text) => {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text);
  };
  const account = (name, records) =>
    write(path.join(root, "Game", "WTF", "Account", name, "SavedVariables", "OneKeyFishing.lua"), savedFile(records));
  account("ONE", { [A]: record(A, 0, 3, { "1.60.1": { "1415:3:47": cell(10, 1, { 6291: [6, 7], 6303: [4, 4] },
    { px: 4300, py: 7800 }) } }) });
  account("TWO", { [B]: record(B, 0, 1, { "1.60.1": { "1415:3:47": cell(5, 0, { 6291: [5, 5] }),
    "1416:2:x": cell(3, 0, { 6358: [3, 3] }) } }) });
  const friend = path.join(root, "friend.lua");
  write(friend, savedFile({
    [F]: oneCell(F, 0, 2, "1415:3:47", cell(2, 0, { 6291: [2, 2] }, { p: { c: 1, i: { 6291: [1, 1] } } })),
    [BAD]: record(BAD, 0, 1, { "1.60.1": { "1415:3:47": { c: 900, m: 0, t: 120, i: {} } } }),
  }));
  const broken = path.join(root, "broken.lua");
  write(broken, "OneKeyFishingDB = { this is not lua");
  const outDir = path.join(root, "out");
  return { root, addonsDir, friend, broken, outDir };
}

function readSeed(outDir) {
  const text = fs.readFileSync(path.join(outDir, "OneKeyFishing", "SeedData.lua"), "utf8");
  return { text, store: JSON.parse(fs.readFileSync(path.join(outDir, "seed", "contributions.json"), "utf8")) };
}

// The seed's cells, read back from the written Lua with the harvest's own reader; item and pool entries as
// [catches, pieces] arrays.
function seedCells(text) {
  const items = (table) => Object.fromEntries(Object.entries(table).map(([id, entry]) => [id, [entry[1], entry[2]]]));
  return Object.fromEntries(Object.entries(parseSeed(text).cells).map(([key, cell]) => [key, {
    ...cell, i: items(cell.i), ...(cell.p ? { p: { c: cell.p.c, i: items(cell.p.i) } } : {}),
  }]));
}

const NOW = new Date("2026-12-01T12:00:00Z");

function run(env, extra = {}) {
  return harvest({ addonsDir: env.addonsDir, files: [env.friend, env.broken], outDir: env.outDir, now: NOW, ...extra });
}

// A minimal CBOR encoder (RFC 8949) for the size check of part 4: maps, arrays, unsigned and negative integers and
// text strings, the subset a record uses. Map keys that are whole numbers in text ("1519") are encoded as integers,
// as the game encodes a Lua table's number keys. The game's encoder may differ by a few bytes; V18 confirms the size
// in game.
function cborHead(major, value) {
  if (value < 24) {
    return Buffer.from([(major << 5) | value]);
  }
  const sizes = [[0xff, 24, 1], [0xffff, 25, 2], [0xffffffff, 26, 4]];
  for (const [max, info, bytes] of sizes) {
    if (value <= max) {
      const out = Buffer.alloc(1 + bytes);
      out[0] = (major << 5) | info;
      out.writeUIntBE(value, 1, bytes);
      return out;
    }
  }
  throw new Error(`too large for this encoder: ${value}`);
}

function cbor(value) {
  if (typeof value === "number") {
    if (!Number.isInteger(value)) {
      throw new Error(`not an integer: ${value}`);
    }
    return value >= 0 ? cborHead(0, value) : cborHead(1, -1 - value);
  }
  if (typeof value === "string") {
    const bytes = Buffer.from(value, "utf8");
    return Buffer.concat([cborHead(3, bytes.length), bytes]);
  }
  if (Array.isArray(value)) {
    return Buffer.concat([cborHead(4, value.length), ...value.map(cbor)]);
  }
  const entries = Object.entries(value);
  return Buffer.concat([cborHead(5, entries.length), ...entries.flatMap(([key, field]) =>
    [cbor(/^\d+$/.test(key) ? Number(key) : key), cbor(field)])]);
}

// The record as the exchange sends it: CBOR, then raw Deflate, then Base64 (Share.lua, research R4 of part 2).
const encodedSize = (record) => zlib.deflateRawSync(cbor(record)).toString("base64").length;

export const tests = [
  {
    name: "harvest sums every valid record of every account and file",
    fn() {
      const env = setup();
      const result = run(env);
      assert.equal(result.ok, true, result.report.join("\n"));
      const cells = seedCells(readSeed(env.outDir).text);
      assert.deepEqual(cells["1415:3:47"], { c: 17, m: 1, t: 180, px: 4300, py: 7800, k: 3,
        i: { 6291: [13, 14], 6303: [4, 4] }, p: { c: 1, i: { 6291: [1, 1] } } });
      assert.deepEqual(cells["1416:2:x"], { c: 3, m: 0, t: 30, k: 1, i: { 6358: [3, 3] } });
    },
  },
  {
    name: "a broken file is rejected; a cell with impossible numbers is skipped, the rest is used",
    fn() {
      const env = setup();
      const report = run(env).report.join("\n");
      // two accounts, the friend's file and the broken one; A, B, F and BAD; only the broken file is rejected
      assert.match(report, /4 file\(s\), 4 record\(s\) read, 1 rejected/);
      assert.match(report, /rejected {2}broken\.lua: does not parse/);
      assert.match(report, /skipped {3}xxxxxxx2 cell 1415:3:47: 900 casts in 120 s of casting/);
      const { store } = readSeed(env.outDir);
      assert.ok(store.contributions[`${F}@0`], "the friend's good record is kept");
      assert.deepEqual(store.contributions[`${BAD}@0`].builds, { "1.60.1": {} }, "without the bad cell");
      assert.equal(seedCells(readSeed(env.outDir).text)["1415:3:47"].c, 17, "the bad cell is not counted");
    },
  },
  {
    name: "the epoch grows by one and absorbed names every contribution unit with the seq summed",
    fn() {
      const env = setup();
      run(env);
      const { text, store } = readSeed(env.outDir);
      assert.match(text, /^ {2}epoch = 1,$/m);
      assert.match(text, /^ {2}built = "2026-12-01",$/m);
      assert.match(text, /^ {2}build = "1\.60\.1",$/m);
      for (const [id, seq] of [[A, 3], [B, 1], [F, 2]]) {
        assert.match(text, new RegExp(`^ {4}\\["${id}"\\] = \\{ \\[0\\] = ${seq} \\},$`, "m"), id);
      }
      assert.deepEqual(parseSeed(text).absorbed[A], { 0: 3 }, "read back as epoch -> seq");
      assert.equal(store.epoch, 1);
    },
  },
  {
    name: "running again with the same files gives the same sums",
    fn() {
      const env = setup();
      run(env);
      const first = seedCells(readSeed(env.outDir).text);
      const second = run(env);
      assert.match(second.report.join("\n"), /New places: 0 {3}New items: 0/);
      assert.match(second.report.join("\n"), /Nothing new: OneKeyFishing\/SeedData\.lua stays at epoch 1/);
      assert.deepEqual(seedCells(readSeed(env.outDir).text), first);
      assert.match(readSeed(env.outDir).text, /^ {2}epoch = 1,$/m, "the epoch does not move without new data");
    },
  },
  {
    name: "a newer seq replaces the stored record instead of adding to it",
    fn() {
      const env = setup();
      run(env);
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 6, "1415:3:47", cell(6, 0, { 6291: [6, 6] })) }));
      run(env);
      assert.equal(seedCells(readSeed(env.outDir).text)["1415:3:47"].c, 10 + 5 + 6);
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 4, "1415:3:47", cell(50, 0, { 6291: [50, 50] })) }));
      run(env);
      assert.equal(seedCells(readSeed(env.outDir).text)["1415:3:47"].c, 21, "an older seq is ignored");
    },
  },
  {
    name: "a reset leaves out the map's data of older game versions",
    fn() {
      const env = setup();
      fs.writeFileSync(env.friend, savedFile({ [F]: record(F, 0, 2, {
        "1.60.1": { "1415:3:47": cell(2, 0, { 6291: [2, 2] }) },
        "1.60.2": { "1415:3:47": cell(4, 0, { 6291: [4, 4] }), "1416:2:x": cell(1, 0, { 6358: [1, 1] }) },
      }) }));
      const report = run(env, { reset: ["1415"] }).report.join("\n");
      assert.match(report, /Reset: map 1415 \(data before 1\.60\.2 left out\)/);
      const { text, store } = readSeed(env.outDir);
      const cells = seedCells(text);
      assert.equal(cells["1415:3:47"].c, 4, "only the 1.60.2 data of map 1415");
      assert.equal(cells["1416:2:x"].c, 3 + 1, "other maps keep every version");
      assert.deepEqual(store.resets, { 1415: "1.60.2" });
      assert.match(text, /^ {4}\[1415\] = "1\.60\.2",$/m);
    },
  },
  {
    name: "a seed over 1 MB is not written",
    fn() {
      const env = setup();
      const big = {};
      for (let n = 0; n < 4; n += 1) {
        const id = `${"cdeg"[n]}${"cdeg"[n]}aaaaaa`;
        const cells = {};
        for (let spot = 0; spot < 1500; spot += 1) {
          const items = {};
          for (let item = 0; item < 12; item += 1) {
            items[10000 + item] = [1, 1];
          }
          const key = `${2000 + n * 100 + Math.floor(spot / 100)}:3:${String(spot % 100).padStart(2, "0")}`;
          cells[key] = cell(12, 0, items);
        }
        big[id] = record(id, 0, 1000, { "1.60.1": cells }); // 180,000 s of casting: 1,000 version steps
      }
      fs.writeFileSync(env.friend, savedFile(big));
      const result = run(env);
      assert.equal(result.ok, false);
      assert.match(result.report.join("\n"), /more than the 1 MB limit; nothing was written/);
      assert.equal(fs.existsSync(path.join(env.outDir, "OneKeyFishing", "SeedData.lua")), false);
      assert.equal(fs.existsSync(path.join(env.outDir, "seed", "contributions.json")), false);
    },
  },
  {
    name: "the written seed is ASCII, sorted, and no line is longer than 120 characters",
    fn() {
      const env = setup();
      const many = {};
      for (let item = 0; item < 40; item += 1) {
        many[20000 + item] = [1, 1];
      }
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 3, "1415:3:00", cell(40, 0, many)) }));
      run(env);
      const { text } = readSeed(env.outDir);
      assert.equal(/[^\x00-\x7f]/.test(text), false, "ASCII");
      for (const line of text.split("\n")) {
        assert.ok(line.length <= 120, `line of ${line.length}: ${line}`);
      }
      const keys = [...text.matchAll(/^ {4}\["(\d+:\d:(?:\d\d|x))"\]/gm)].map((m) => m[1]);
      assert.deepEqual(keys, [...keys].sort(), "sorted keys");
      assert.equal(Object.keys(seedCells(text)["1415:3:00"].i).length, 40, "every item of a wrapped cell");
    },
  },
  {
    name: "--synthetic writes a valid random seed and leaves the contributions alone",
    fn() {
      const env = setup();
      const result = harvest({ synthetic: 300, outDir: env.outDir, now: NOW });
      assert.equal(result.ok, true);
      assert.match(result.report.join("\n"), /synthetic seed: do not commit/);
      const text = fs.readFileSync(path.join(env.outDir, "OneKeyFishing", "SeedData.lua"), "utf8");
      const cells = seedCells(text);
      assert.ok(Object.keys(cells).length > 250, "about 300 places (random keys may repeat)");
      for (const [key, value] of Object.entries(cells)) {
        assert.match(key, /^\d+:[0-4]:\d\d$/);
        assert.ok(value.c + value.m <= value.t, key);
      }
      assert.equal(fs.existsSync(path.join(env.outDir, "seed", "contributions.json")), false);
    },
  },
  {
    name: "a cell with px but no py is skipped",
    fn() {
      const env = setup();
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 2, "1415:3:47", cell(2, 0, { 6291: [2, 2] },
        { px: 900 })) }));
      const report = run(env).report.join("\n");
      assert.match(report, /skipped {3}ffffffff cell 1415:3:47: px and py come together/);
      assert.equal(/NaN/.test(readSeed(env.outDir).text), false, "no NaN in the seed");
    },
  },
  {
    name: "k counts the players of a cell, not their records of different epochs",
    fn() {
      const env = setup();
      run(env);
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 1, 1, "1415:3:47", cell(3, 0, { 6291: [3, 3] })) }));
      run(env);
      const sum = seedCells(readSeed(env.outDir).text)["1415:3:47"];
      assert.equal(sum.c, 17 + 3, "both epochs of the friend count");
      assert.equal(sum.k, 3, "A, B and the friend");
    },
  },
  {
    name: "the epoch never goes back, also when the contributions file is lost",
    fn() {
      const env = setup();
      run(env); // epoch 1
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 5, "1415:3:47", cell(9, 0, { 6291: [9, 9] })) }));
      run(env); // new sums: epoch 2
      fs.rmSync(path.join(env.outDir, "seed", "contributions.json")); // the store starts again at epoch 0
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 6, "1415:3:47", cell(12, 0, { 6291: [12, 12] })) }));
      run(env);
      assert.match(readSeed(env.outDir).text, /^ {2}epoch = 3,$/m, "after the shipped seed's epoch 2, not 1");
    },
  },
  {
    name: "other players' records in the author's file go in once each, with the newest seq",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-network-"));
      const G = "gggggggg";
      const H = "hhhhhhhh";
      const J = "jjjjjjjj";
      const withSeen = (value) => ({ ...value, seen: 1761234567 });
      const author = path.join(root, "author.lua");
      fs.writeFileSync(author, savedFile({
        [A]: oneCell(A, 0, 5, "1415:3:47", cell(10, 0, { 6291: [10, 10] })),
        [`${G}@1`]: withSeen(oneCell(G, 1, 2, "1415:3:47", cell(4, 0, { 6291: [4, 4] }))),
        [`${H}@0`]: withSeen(oneCell(H, 0, 6, "1415:3:47", cell(6, 0, { 6291: [6, 6] }))),
        [`${J}@2`]: withSeen(oneCell(J, 2, 1, "1416:2:x", cell(3, 0, { 6358: [3, 3] }))),
      }));
      const other = path.join(root, "other.lua");
      fs.writeFileSync(other, savedFile({
        [`${H}@0`]: withSeen(oneCell(H, 0, 2, "1415:3:47", cell(2, 0, { 6291: [2, 2] }))),
      }));
      const outDir = path.join(root, "out");
      const result = harvest({ files: [author, other], outDir, now: NOW });
      assert.equal(result.ok, true, result.report.join("\n"));
      assert.match(result.report.join("\n"), /Contributions: 4 \(each <id>@<epoch> once/);
      const { text, store } = readSeed(outDir);
      assert.deepEqual(Object.keys(store.contributions).sort(), [`${A}@0`, `${G}@1`, `${H}@0`, `${J}@2`]);
      assert.equal(store.contributions[`${H}@0`].seq, 6, "the newer seq of the duplicate");
      assert.equal(store.contributions[`${G}@1`].seen, undefined, "seen is not kept");
      const cells = seedCells(text);
      assert.equal(cells["1415:3:47"].c, 10 + 4 + 6, "each contribution once");
      assert.equal(cells["1415:3:47"].k, 3, "three players there");
      assert.equal(cells["1416:2:x"].c, 3);
      for (const [id, epoch, seq] of [[A, 0, 5], [G, 1, 2], [H, 0, 6], [J, 2, 1]]) {
        assert.match(text, new RegExp(`^ {4}\\["${id}"\\] = \\{ \\[${epoch}\\] = ${seq} \\},$`, "m"), id);
      }
      const again = harvest({ files: [author, other], outDir, now: NOW });
      assert.match(again.report.join("\n"), /Nothing new: OneKeyFishing\/SeedData\.lua stays at epoch 1/);
    },
  },
  {
    name: "a received copy older than its owner's record: the seed names its seq, a newer seq goes in next time",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-partial-"));
      const X = "xxxxxxxx";
      const author = path.join(root, "author.lua");
      const outDir = path.join(root, "out");
      // The author's client got X's record at seq 25 (25 catches); X is already further.
      fs.writeFileSync(author, savedFile({
        [A]: oneCell(A, 0, 1, "1415:3:47", cell(1, 0, { 6291: [1, 1] })),
        [`${X}@0`]: oneCell(X, 0, 25, "1415:3:47", cell(25, 0, { 6291: [25, 25] })),
      }));
      harvest({ files: [author], outDir, now: NOW });
      assert.deepEqual(parseSeed(readSeed(outDir).text).absorbed[X], { 0: 25 }, "held up to seq 25");
      // After the release X's own client keeps its seq 40 version (frozen) and peers pass it on: it comes back.
      fs.writeFileSync(author, savedFile({
        [A]: oneCell(A, 0, 1, "1415:3:47", cell(1, 0, { 6291: [1, 1] })),
        [`${X}@0`]: oneCell(X, 0, 40, "1415:3:47", cell(40, 0, { 6291: [40, 40] })),
        [`${X}@1`]: oneCell(X, 1, 3, "1415:3:47", cell(3, 0, { 6291: [3, 3] })),
      }));
      harvest({ files: [author], outDir, now: NOW });
      const { text } = readSeed(outDir);
      assert.deepEqual(parseSeed(text).absorbed[X], { 0: 40, 1: 3 }, "both units, each with its seq");
      assert.equal(seedCells(text)["1415:3:47"].c, 1 + 40 + 3, "the newer seq replaced the older, no catch twice");
    },
  },
  {
    name: "a record whose seq is above its casts is rejected: a made-up seq never replaces the real one",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-seq-"));
      const X = "xxxxxxxx";
      const author = path.join(root, "author.lua");
      const outDir = path.join(root, "out");
      fs.writeFileSync(author, savedFile({
        [A]: oneCell(A, 0, 1, "1415:3:47", cell(1, 0, { 6291: [1, 1] })),
        [`${X}@0`]: oneCell(X, 0, 4, "1415:3:47", cell(4, 0, { 6291: [4, 4] })),
      }));
      harvest({ files: [author], outDir, now: NOW });
      fs.writeFileSync(author, savedFile({
        [A]: oneCell(A, 0, 1, "1415:3:47", cell(1, 0, { 6291: [1, 1] })),
        [`${X}@0`]: oneCell(X, 0, 1000000, "1415:3:47", cell(5, 0, { 6291: [5, 5] })),
      }));
      const report = harvest({ files: [author], outDir, now: NOW }).report.join("\n");
      assert.match(report, /rejected {2}author\.lua xxxx\.\.\.: seq 1000000 is above the record's 5 casts/);
      assert.equal(readSeed(outDir).store.contributions[`${X}@0`].seq, 4, "the real version stays");
    },
  },
  {
    name: "npm run check finds a malformed absorbed entry",
    fn() {
      const text = (absorbed) => "local _, ns = ...\nns.SeedData = { epoch = 1, built = \"\", build = \"\", "
        + `absorbed = ${absorbed}, resets = {}, cells = {} }\n`;
      const problems = (absorbed) => seedProblems(luaparse.parse(text(absorbed), { luaVersion: "5.1" }));
      assert.deepEqual(problems(`{ ["${A}"] = { [0] = 3, [2] = 7 } }`), []);
      assert.equal(problems(`{ ["${A}"] = 0 }`).length, 1, "the old form, an epoch only");
      assert.equal(problems(`{ ["${A}"] = { [0] = -1 } }`).length, 1, "a negative seq");
      assert.equal(problems(`{ ["${A}"] = {} }`).length, 1, "no unit");
    },
  },
  {
    name: "a reset with no contributions to reset fails instead of doing nothing",
    fn() {
      const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-empty-"));
      const result = harvest({ files: [], outDir, now: NOW, reset: ["1415"] });
      assert.equal(result.ok, false);
      assert.match(result.report.join("\n"), /--reset 1415: no contributions with a game version yet/);
    },
  },
  // --- Part 3 (specs/004-public-channel-sync): the version chain, the casting limit, the weights --------------
  {
    name: "a link step is the same in Node as in the game's Lua (tests/proof_test.lua)",
    fn() {
      assert.equal(proofStep("abcdefghijklmnop"), "6oo2y3f2xjjv4lba");
      assert.equal(proofStep(proofStep("abcdefghijklmnop")), "sbb5d3yn6x6u3vuz");
    },
  },
  {
    name: "a newer version that does not continue the stored one's chain is rejected; the stored one stays",
    fn() {
      const env = setup();
      run(env);
      const forged = oneCell(F, 0, 6, "1415:3:47", cell(60, 0, { 6291: [60, 60] }));
      forged.proof = proofFor("a forger", 6);
      fs.writeFileSync(env.friend, savedFile({ [F]: forged }));
      const result = run(env);
      assert.match(result.report.join("\n"),
        /rejected {2}friend\.lua ffff\.\.\.: the proof does not continue the stored version/);
      assert.equal(readSeed(env.outDir).store.contributions[`${F}@0`].seq, 2, "the stored version stays");
      assert.match(result.report.join("\n"), /Disputed: ffffffff@0: versions that are not on one chain/);
      const seed = parseSeed(readSeed(env.outDir).text);
      assert.equal(seed.proofs[F] || seed.absorbed[F], undefined, "left out of the seed: no proof, not absorbed");
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 6, "1415:3:47", cell(6, 0, { 6291: [6, 6] })) }));
      run(env);
      assert.equal(readSeed(env.outDir).store.contributions[`${F}@0`].seq, 6, "the owner's version goes in");
    },
  },
  {
    name: "a made-up version met before the owner's lower one: disputed, kept so, and left out of the seed",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-disputed-"));
      const author = path.join(root, "author.lua");
      const friend = path.join(root, "friend.lua");
      const forged = oneCell("uaaaaaa2", 0, 400, "1415:3:47", cell(400, 0, { 6291: [400, 400] }));
      forged.proof = proofFor("a forger", 400);
      forged.builds = { "99.0.0": forged.builds["1.60.1"] }; // any game version a forger likes
      fs.writeFileSync(author, savedFile({ "uaaaaaa2@0": forged }));
      fs.writeFileSync(friend, savedFile({ "uaaaaaa2@0": oneCell("uaaaaaa2", 0, 50, "1415:3:47",
        cell(50, 0, { 6291: [50, 50] })) }));
      const outDir = path.join(root, "out");
      const result = harvest({ files: [author, friend], outDir, now: NOW });
      assert.match(result.report.join("\n"), /Disputed: uaaaaaa2@0: versions that are not on one chain/);
      let seed = parseSeed(readSeed(outDir).text);
      assert.equal(seed.proofs.uaaaaaa2 || seed.absorbed.uaaaaaa2, undefined,
        "left out of the seed: clients keep and pass on their copies, none is deleted or refused");
      assert.equal(seedCells(readSeed(outDir).text)["1415:3:47"], undefined, "in no sum");
      harvest({ files: [author], outDir, now: NOW }); // the next ordinary run, without the friend's file
      seed = parseSeed(readSeed(outDir).text);
      assert.equal(seed.proofs.uaaaaaa2 || seed.absorbed.uaaaaaa2, undefined, "still left out: the dispute is kept");
      // The disputed version's far newer game version decides neither the seed's build nor a reset.
      const friend2 = path.join(root, "friend2.lua");
      fs.writeFileSync(friend2, savedFile({ "vaaaaaa2@0": oneCell("vaaaaaa2", 0, 5, "1415:3:46",
        cell(5, 0, { 6291: [5, 5] })) }));
      const result2 = harvest({ files: [friend2], outDir, now: NOW, reset: ["1415"] });
      assert.match(result2.report.join("\n"), /Reset: map 1415 \(data before 1\.60\.1 left out\)/);
      assert.equal(parseSeed(readSeed(outDir).text).build, "1.60.1", "the seed's build");
    },
  },
  {
    name: "a stored version without a proof (before part 3) and a lower one with a proof: no dispute, no error",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-noproof-"));
      const outDir = path.join(root, "out");
      const old = oneCell("uaaaaaa2", 0, 60, "1415:3:47", cell(60, 0, { 6291: [60, 60] }));
      delete old.proof;
      fs.mkdirSync(path.join(outDir, "seed"), { recursive: true });
      fs.writeFileSync(path.join(outDir, "seed", "contributions.json"),
        JSON.stringify({ epoch: 1, resets: {}, contributions: { "uaaaaaa2@0": old }, blocked: {} }));
      const file = path.join(root, "friend.lua");
      fs.writeFileSync(file, savedFile({ "uaaaaaa2@0": oneCell("uaaaaaa2", 0, 50, "1415:3:47",
        cell(50, 0, { 6291: [50, 50] })) }));
      const report = harvest({ files: [file], outDir, now: NOW }).report.join("\n");
      assert.doesNotMatch(report, / {2}rejected {2}|Disputed/, report);
    },
  },
  {
    name: "a record without a proof, or with more casting than its version steps allow, is rejected",
    fn() {
      const env = setup();
      const noProof = oneCell(F, 0, 2, "1415:3:47", cell(2, 0, { 6291: [2, 2] }));
      delete noProof.proof;
      const tooMuch = oneCell("gggggggg", 0, 1, "1415:3:47", cell(19, 0, { 6291: [19, 19] })); // 190 s in 1 step
      fs.writeFileSync(env.friend, savedFile({ [F]: noProof, gggggggg: tooMuch }));
      const report = run(env).report.join("\n");
      assert.match(report, /the proof is not 16 base32 characters/);
      assert.match(report, /more casting than 1 version steps allow/);
    },
  },
  {
    name: "the seed carries the proof of every absorbed version, and npm run check finds a malformed one",
    fn() {
      const env = setup();
      run(env);
      const seed = parseSeed(readSeed(env.outDir).text);
      assert.deepEqual(seed.proofs[A], { 0: proofFor(A, 3) });
      assert.deepEqual(seed.proofs[F], { 0: proofFor(F, 2) });
      assert.deepEqual(seed.blocked, {});
      const bad = readSeed(env.outDir).text.replace(proofFor(A, 3), "short");
      assert.ok(seedProblems(luaparse.parse(bad, { luaVersion: "5.1" })).some((p) => p.includes("proofs[")));
    },
  },
  {
    name: "from five contributors on, one contribution carries at most a fifth of a cell, within the cell rules",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-weights-"));
      const file = path.join(root, "author.lua");
      const records = {};
      for (const id of ["caaaaaa2", "daaaaaa2", "eaaaaaa2", "faaaaaa2"]) {
        records[id] = oneCell(id, 0, 1, "1415:3:47", cell(10, 0, { 6291: [10, 10] }));
      }
      // 900 catches, all with one item: capped at a fifth of the weighted total, (40 + T) / 5 = T.
      records.gaaaaaa2 = oneCell("gaaaaaa2", 0, 50, "1415:3:47",
        cell(900, 0, { 6303: [900, 900] }, { px: 9000, py: 9000 }));
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const c = seedCells(readSeed(outDir).text)["1415:3:47"];
      assert.equal(c.k, 5, "five contributors");
      assert.equal(c.c, 40 + 10, "the big one counts as 10 catches (40 / 4)");
      assert.equal(c.r, 940, "the raw catches, for the views' little-data threshold and catch count");
      assert.deepEqual(c.i["6303"], [10, 10], "its item scaled the same way");
      assert.ok(c.c + c.m <= c.t, "casts within the seconds");
      assert.ok(c.px <= 1000 * (c.c + c.m), "positions within range");
    },
  },
  {
    name: "a contributor of few catches and many misses holds at most a fifth of a cell's miss rate",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-weights-misses-"));
      const file = path.join(root, "author.lua");
      const records = {};
      for (const id of ["caaaaaa2", "daaaaaa2", "eaaaaaa2", "faaaaaa2", "gaaaaaa2"]) {
        records[id] = oneCell(id, 0, 10, "1415:3:47", cell(100, 20, { 6291: [100, 100] }));
      }
      records.haaaaaa2 = oneCell("haaaaaa2", 0, 200, "1415:3:47", cell(1, 3000, { 6291: [1, 1] }));
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const c = seedCells(readSeed(outDir).text)["1415:3:47"];
      assert.equal(c.k, 6, "six contributors");
      assert.equal(c.c, 501, "no catches capped: the chances stay");
      // Casts: 5 x 120 and 3001, capped at a fifth: (600 + T) / 5 = T = 150.
      assert.equal(c.m, 100 + Math.round(3000 * 150 / 3001), "its misses scaled by its casts' factor");
      assert.equal(c.x, 500, "the catches weighted by casts: 500 + 1 x 150 / 3001");
      assert.ok(Math.abs(c.m / (c.x + c.m) - (100 + 3000 * 150 / 3001) / 750) < 0.001, "the views' miss rate");
      assert.ok(c.x + c.m <= c.t && c.c + c.m <= c.t, "casts within the seconds");
    },
  },
  {
    name: "a weighted contributor's cell without casts keeps its positions at 0, never NaN",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-weights-empty-"));
      const file = path.join(root, "author.lua");
      const records = {};
      for (const id of ["caaaaaa2", "daaaaaa2", "eaaaaaa2", "faaaaaa2", "gaaaaaa2"]) {
        records[id] = oneCell(id, 0, 10, "1415:3:47", cell(100, 20, { 6291: [100, 100] }));
      }
      records.haaaaaa2 = oneCell("haaaaaa2", 0, 200, "1415:3:47", cell(1, 3000, { 6291: [1, 1] }));
      // The same ID's other epoch: a cell without casts at that place (valid), and a real one elsewhere.
      records["haaaaaa2@1"] = record("haaaaaa2", 1, 1, { "1.60.1": {
        "1415:3:47": { c: 0, m: 0, t: 0, i: {}, px: 0, py: 0 },
        "1415:3:48": cell(10, 0, { 6291: [10, 10] }) } });
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const text = readSeed(outDir).text;
      assert.ok(!text.includes("NaN"), "no NaN in the seed");
      assert.equal(seedCells(text)["1415:3:47"].px, 0, "the positions of that cell");
    },
  },
  {
    name: "a contributor capped by its catches only: every miss stays, and x gives the miss rate weighted by casts",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-weights-catches-"));
      const file = path.join(root, "author.lua");
      const records = { caaaaaa2: oneCell("caaaaaa2", 0, 200, "1415:3:47", cell(1000, 1000, { 6291: [1000, 1000] })) };
      for (const id of ["daaaaaa2", "eaaaaaa2", "faaaaaa2", "gaaaaaa2"]) {
        records[id] = oneCell(id, 0, 200, "1415:3:47", cell(100, 1900, { 6291: [100, 100] }));
      }
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const c = seedCells(readSeed(outDir).text)["1415:3:47"];
      assert.equal(c.c, 100 + 400, "the big one capped at 100 catches: (400 + T) / 5 = T");
      assert.deepEqual(c.i["6291"], [500, 500], "its item scaled the same way");
      assert.equal(c.m, 1000 + 4 * 1900, "nobody is over a fifth of the casts: every miss stays");
      assert.equal(c.x, 1000 + 400, "the catches weighted by casts");
      assert.equal(c.m / (c.x + c.m), 0.86, "the views' miss rate is the real one here");
    },
  },
  {
    name: "five contributors with only four catching: nothing is weighted, as in the views",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-weights-few-"));
      const file = path.join(root, "author.lua");
      const records = {};
      for (const [id, catches] of [["caaaaaa2", 40], ["daaaaaa2", 30], ["eaaaaaa2", 20], ["faaaaaa2", 10]]) {
        records[id] = oneCell(id, 0, 5, "1415:3:47", cell(catches, 0, { 6291: [catches, catches] }));
      }
      records.gaaaaaa2 = record("gaaaaaa2", 0, 5, { "1.60.1": { "1415:3:47": cell(0, 10, {}),
        "1415:3:48": cell(0, 5, {}) } });
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const cells = seedCells(readSeed(outDir).text);
      const c = cells["1415:3:47"];
      assert.equal(c.k, 4, "four players: one who only missed is none, as in the views");
      assert.equal(c.r, undefined, "nothing weighted: no raw catches apart");
      assert.equal(cells["1415:3:48"].k, 0, "a cell of misses only has no player");
      assert.equal(c.c, 100, "every catch counts (weighting would have capped each one at 0)");
      assert.equal(c.m, 10, "the misses stay");
      assert.deepEqual(c.i["6291"], [100, 100], "the item unscaled");
    },
  },
  {
    name: "casting under an unknown build does not count against the version steps: the honest record goes in",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-unknown-build-"));
      const file = path.join(root, "author.lua");
      // seq 2 allows 360 s: 120 s under 1.60.1, and 300 s while GetBuildInfo failed (casts that raise no seq).
      const records = { caaaaaa2: record("caaaaaa2", 0, 2, { "1.60.1": { "1415:3:47": cell(12, 0, { 6291: [12, 12] }) },
        unknown: { "1415:3:47": cell(30, 0, { 6291: [30, 30] }) } }) };
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      const result = harvest({ files: [file], outDir, now: NOW });
      assert.equal(result.ok, true, result.report.join("\n"));
      assert.doesNotMatch(result.report.join("\n"), /version steps/);
      assert.equal(seedCells(readSeed(outDir).text)["1415:3:47"].c, 12, "its game-version cell counts");
    },
  },
  {
    name: "a cell's extra fields stay out of the contributions; __proto__ is a plain field, never the prototype",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-fields-"));
      const file = path.join(root, "author.lua");
      const extra = { ...cell(2, 0, { 6291: [2, 2] }), junk: 5, ["__proto__"]: { x: 1 } };
      const inherited = { c: 1, i: {}, ["__proto__"]: { m: 2, t: 9 } }; // m and t only by inheritance
      const records = { caaaaaa2: record("caaaaaa2", 0, 1, { "1.60.1": { "1415:3:47": extra, "1415:3:48": inherited } }) };
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const first = readSeed(outDir);
      const cells = first.store.contributions["caaaaaa2@0"].builds["1.60.1"];
      assert.deepEqual(Object.keys(cells["1415:3:47"]).sort(), ["c", "i", "m", "t"], "only the client's fields");
      assert.equal(cells["1415:3:48"], undefined, "a cell without its own m and t is skipped");
      harvest({ files: [], outDir, now: NOW });
      const second = readSeed(outDir);
      assert.ok(!second.text.includes("NaN"), "no NaN on the next run");
      assert.deepEqual(seedCells(second.text)["1415:3:47"], seedCells(first.text)["1415:3:47"], "the same cell");
      assert.deepEqual(seedProblems(luaparse.parse(second.text, { luaVersion: "5.1" })), [], "npm run check is happy");
    },
  },
  {
    name: "--block takes a following saved file as a file, whatever its name, and anything else as the note",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-args-"));
      const saved = path.join(root, "friend.txt");
      fs.writeFileSync(saved, savedFile({}));
      let args = parseArgs(["--block", "abcdefgh", saved]);
      assert.deepEqual(args.block, [{ id: "abcdefgh", note: "" }], "no note");
      assert.deepEqual(args.files, [path.resolve(saved)], "the file is harvested");
      args = parseArgs(["--block", "abcdefgh", "Friend.LUA"]);
      assert.deepEqual(args.files, [path.resolve("Friend.LUA")], "a .LUA name is a file too");
      args = parseArgs(["--block", "abcdefgh", "made-up catches", saved]);
      assert.deepEqual(args.block, [{ id: "abcdefgh", note: "made-up catches" }], "the note");
      assert.deepEqual(args.files, [path.resolve(saved)], "and the file after it");
      args = parseArgs(["--block", "abcdefgh", root]);
      assert.deepEqual(args.block, [{ id: "abcdefgh", note: root }], "a folder of that name is a note");
      assert.deepEqual(args.files, [], "not a saved file");
      assert.equal(parseArgs(["--synthetic", "x"]).error, "error: --synthetic needs a number of places");
    },
  },
  {
    name: "--block leaves an ID out of the sums and of absorbed, and the seed names it; --unblock takes it back",
    fn() {
      const env = setup();
      run(env);
      const blocked = harvest({ addonsDir: env.addonsDir, files: [env.friend, env.broken], outDir: env.outDir,
        now: NOW, block: [{ id: F, note: "made up" }] });
      assert.match(blocked.report.join("\n"), /Blocked: ffffffff \(made up\)/);
      const { text, store } = readSeed(env.outDir);
      assert.equal(store.blocked[F], "made up", "kept in seed/contributions.json with the note");
      const seed = parseSeed(text);
      assert.equal(seed.blocked[F], true, "the seed names it");
      assert.equal(seed.absorbed[F], undefined, "not absorbed");
      assert.equal(seedCells(text)["1415:3:47"].c, 10 + 5, "its 2 catches are in no sum");
      harvest({ addonsDir: env.addonsDir, files: [env.friend, env.broken], outDir: env.outDir, now: NOW,
        unblock: [F] });
      assert.equal(parseSeed(readSeed(env.outDir).text).blocked[F], undefined, "back");
      assert.equal(seedCells(readSeed(env.outDir).text)["1415:3:47"].c, 10 + 5 + 2, "counted again");
      const bad = harvest({ addonsDir: env.addonsDir, outDir: env.outDir, now: NOW, block: [{ id: "nope" }] });
      assert.equal(bad.ok, false, "a bad ID is an error");
      const seedText = readSeed(env.outDir).text.replace("blocked = {},", 'blocked = { ["nope"] = true },');
      assert.ok(seedProblems(luaparse.parse(seedText, { luaVersion: "5.1" })).some((p) => p.includes("blocked[")));
    },
  },
  {
    name: "the outlier report points at fast casting, odd item shares, lone items and odd pieces, not at honest data",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-outliers-"));
      const file = path.join(root, "author.lua");
      const records = {};
      const keys = ["1415:3:41", "1415:3:42", "1415:3:43"];
      // Four honest players: 40 catches of FISH at each of three cells, 10 s per cast.
      for (const id of ["caaaaaa3", "daaaaaa3", "eaaaaaa3", "faaaaaa3"]) {
        records[id] = record(id, 0, 10, { "1.60.1": Object.fromEntries(keys.map((key) =>
          [key, cell(40, 0, { 6291: [40, 40] })])) });
      }
      // One that casts every second, catches only a rare item there, and brings an item nobody else has.
      const odd = record("gaaaaaa3", 0, 3, { "1.60.1": Object.fromEntries(keys.map((key) =>
        [key, { c: 60, m: 0, t: 60, i: { 6303: [60, 60], 99999: [1, 1] } }])) });
      records.gaaaaaa3 = odd;
      // One with five times the pieces per catch of FISH.
      records.haaaaaa3 = record("haaaaaa3", 0, 10, { "1.60.1": { "1415:3:41": cell(30, 0, { 6291: [30, 150] }) } });
      fs.writeFileSync(file, savedFile(records));
      const report = harvest({ files: [file], outDir: path.join(root, "out"), now: NOW }).report.join("\n");
      const oddLine = report.split("\n").find((line) => line.startsWith("  outlier   gaaaaaa3@0: ")) || "";
      assert.match(oddLine, /casts every 1\.0 s on average/);
      assert.match(oddLine, /item shares unlike the others' at 3 cells/);
      assert.match(oddLine, /items nobody else reports: 6303, 99999/);
      assert.match(report, /outlier {3}haaaaaa3@0: pieces per catch 3 times the others'/);
      assert.doesNotMatch(report, /outlier {3}caaaaaa3/, "an honest player");
      assert.match(report, /block one with: npm run harvest -- --block <id> "why"/);
    },
  },

  {
    name: "subzone counts are checked, summed per area, kept to the 8 largest, written sorted and checked (part 4)",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-areas-"));
      const file = path.join(root, "author.lua");
      const areas = (a) => ({ px: 1000, py: 1000, a });
      fs.writeFileSync(file, savedFile({
        [A]: oneCell(A, 0, 5, "1415:3:47", cell(10, 0, { 6291: [10, 10] },
          areas({ 1519: 5, 10: 2, 11: 1, 12: 1, 13: 1 }))),
        [`${B}@0`]: record(B, 0, 5, { "1.60.1": {
          "1415:3:47": cell(10, 0, { 6291: [10, 10] }, areas({ 1519: 3, 14: 3, 15: 2, 16: 1, 17: 1 })),
          "1415:3:48": cell(2, 0, { 6291: [2, 2] }, areas({ 1519: 9 })), // more casts in areas than in the cell
        } }),
      }));
      const outDir = path.join(root, "out");
      const result = harvest({ files: [file], outDir, now: NOW });
      assert.equal(result.ok, true, result.report.join("\n"));
      assert.match(result.report.join("\n"), /skipped {3}bbbbbbbb cell 1415:3:48: more casts in areas than in the cell/);
      const { text, store } = readSeed(outDir);
      assert.deepEqual(store.contributions[`${A}@0`].builds["1.60.1"]["1415:3:47"].a,
        { 10: 2, 11: 1, 12: 1, 13: 1, 1519: 5 }, "kept in the contribution");
      const c = seedCells(text)["1415:3:47"];
      // Nine areas in the sum: 1519 8, 14 3, 10 2, 15 2, then 11, 12, 13, 16, 17 with 1 each: the lowest IDs stay.
      assert.deepEqual(c.a, { 10: 2, 11: 1, 12: 1, 13: 1, 14: 3, 15: 2, 16: 1, 1519: 8 }, "the 8 largest");
      assert.match(text, /^ {6}a = \{ \[10\] = 2, \[11\] = 1, \[12\] = 1, \[13\] = 1, \[14\] = 3, \[15\] = 2, \[16\] = 1, \[1519\] = 8 \},$/m,
        "sorted by ID");
      assert.deepEqual(seedProblems(luaparse.parse(text, { luaVersion: "5.1" })), [], "npm run check is happy");
      const bad = text.replace("[1519] = 8 },", "[1519] = 80 },");
      assert.ok(seedProblems(luaparse.parse(bad, { luaVersion: "5.1" }))
        .some((problem) => problem.includes("more casts in areas")), "a bad seed cell is a problem");
    },
  },
  {
    name: "a weighted contributor's subzone counts are scaled by its cast factor, within the cell's casts",
    fn() {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-areas-weights-"));
      const file = path.join(root, "author.lua");
      const records = {};
      for (const id of ["caaaaaa4", "daaaaaa4", "eaaaaaa4", "faaaaaa4"]) {
        records[id] = oneCell(id, 0, 1, "1415:3:47", cell(10, 0, { 6291: [10, 10] }, { px: 100, py: 100,
          a: { 40: 10 } }));
      }
      records.gaaaaaa4 = oneCell("gaaaaaa4", 0, 50, "1415:3:47", cell(900, 0, { 6303: [900, 900] },
        { px: 9000, py: 9000, a: { 30: 899, 31: 1 } }));
      const outDir = path.join(root, "out");
      fs.writeFileSync(file, savedFile(records));
      harvest({ files: [file], outDir, now: NOW });
      const c = seedCells(readSeed(outDir).text)["1415:3:47"];
      assert.equal(c.a["40"], 40, "the four others in full");
      assert.equal(c.a["30"], 10, "899 casts scaled like the 900 casts: 10");
      assert.equal(c.a["31"], undefined, "one cast scaled to nothing");
      const total = Object.values(c.a).reduce((sum, n) => sum + n, 0);
      assert.ok(total <= c.c + c.m, "within the cell's casts");
    },
  },
  {
    name: "a 500-place record with two subzones per place encodes under 28 KB (V18)",
    fn() {
      const cells = {};
      for (let i = 0; i < 500; i += 1) {
        const key = `${1400 + (i % 50)}:${i % 5}:${String(Math.floor(i / 5) % 100).padStart(2, "0")}`;
        cells[key] = { c: 300 + i, m: 40, t: 4000 + i, px: 150000 + i * 7, py: 120000 + i * 11,
          i: { 6291: [200, 210], 6303: [80, 80], 6358: [20 + (i % 7), 25] }, a: { [1500 + i]: 250, [2000 + i]: 90 } };
      }
      const size = encodedSize({ id: A, epoch: 3, seq: 4000, proof: "abcdefghijklmnop", builds: { "1.60.1": cells } });
      assert.ok(size < 28 * 1024, `${size} bytes`);
    },
  },
];
