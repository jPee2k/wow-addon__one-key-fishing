// tools/harvest.mjs: saved files in a temporary game tree -> seed/contributions.json and OneKeyFishing/SeedData.lua
// in a temporary output folder. Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { harvest, parseSeed } from "../tools/harvest.mjs";

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
const record = (id, epoch, seq, builds) => ({ id, epoch, seq, builds });
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
    name: "the epoch grows by one and absorbed names every contribution with its newest epoch",
    fn() {
      const env = setup();
      run(env);
      const { text, store } = readSeed(env.outDir);
      assert.match(text, /^ {2}epoch = 1,$/m);
      assert.match(text, /^ {2}built = "2026-12-01",$/m);
      assert.match(text, /^ {2}build = "1\.60\.1",$/m);
      for (const id of [A, B, F]) {
        assert.match(text, new RegExp(`^ {4}\\["${id}"\\] = 0,$`, "m"), id);
      }
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
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 9, "1415:3:47", cell(6, 0, { 6291: [6, 6] })) }));
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
        big[id] = record(id, 0, 1, { "1.60.1": cells });
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
      fs.writeFileSync(env.friend, savedFile({ [F]: oneCell(F, 0, 2, "1415:3:00", cell(40, 0, many)) }));
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
    name: "a reset with no contributions to reset fails instead of doing nothing",
    fn() {
      const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "okf-harvest-empty-"));
      const result = harvest({ files: [], outDir, now: NOW, reset: ["1415"] });
      assert.equal(result.ok, false);
      assert.match(result.report.join("\n"), /--reset 1415: no contributions with a game version yet/);
    },
  },
];
