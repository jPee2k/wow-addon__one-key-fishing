// tools/addon.mjs markerVerdict: what open VERIFY markers mean for `npm run check`, `npm run build` (--release) and
// `npm run build -- --force` (--release --force: they ship, with a warning). Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import { markerVerdict } from "../../tools/addon.mjs";

const MARKERS = ["OneKeyFishing/Catch/Catch.lua:39 V51 quality", "OneKeyFishing/Exchange/Channel.lua:12 V21 hidden"];

export const tests = [
  {
    name: "a normal check lists the markers and finds no problem",
    fn: () => {
      assert.deepEqual(markerVerdict(MARKERS), { problems: [], list: MARKERS, forced: false });
    },
  },
  {
    name: "a release refuses every open marker",
    fn: () => {
      const verdict = markerVerdict(MARKERS, { release: true });
      assert.equal(verdict.problems.length, 2);
      assert.match(verdict.problems[0], /^OneKeyFishing\/Catch\/Catch\.lua:39 V51 quality: open VERIFY marker/);
      assert.deepEqual(verdict.list, []);
      assert.equal(verdict.forced, false);
    },
  },
  {
    name: "a forced release ships the markers and lists them as a warning",
    fn: () => {
      assert.deepEqual(markerVerdict(MARKERS, { release: true, force: true }),
        { problems: [], list: MARKERS, forced: true });
    },
  },
  {
    name: "--force without markers warns of nothing; --force without --release changes nothing",
    fn: () => {
      assert.deepEqual(markerVerdict([], { release: true, force: true }), { problems: [], list: [], forced: false });
      assert.deepEqual(markerVerdict(MARKERS, { force: true }), { problems: [], list: MARKERS, forced: false });
    },
  },
];
