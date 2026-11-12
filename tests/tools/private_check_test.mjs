// tools/addon.mjs privateProblems: the npm run check rule that a module's private table is read only by the files
// of its own folder (specs/008-architecture-alignment contracts C4). Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import { privateProblems } from "../../tools/addon.mjs";

const folders = { CatchDB: "CatchDB", Share: "Exchange", Comm: "Exchange" };
const folderOf = (name) => folders[name];

export const tests = [
  {
    name: "a file of the module's folder may read its private table",
    fn: () => {
      assert.deepEqual(privateProblems("local P = CatchDB.private\nlocal P2 = ns.CatchDB.private\n", "CatchDB",
        folderOf), []);
      assert.deepEqual(privateProblems("local P = Comm.private\n", "Exchange", folderOf), []);
    },
  },
  {
    name: "another folder reading it is a problem, with its line",
    fn: () => {
      const problems = privateProblems("local x = 1\nlocal ready = ns.CatchDB.private.OwnProofReady()\n", "Exchange",
        folderOf);
      assert.equal(problems.length, 1);
      assert.equal(problems[0].line, 2);
    },
  },
  {
    name: "comments, lower-case locals and unknown names are not read",
    fn: () => {
      const text = "-- Shared through CatchDB.private\nlocal P = {}\nP.private = 1\nFoo.private = 2\n";
      assert.deepEqual(privateProblems(text, "UI", folderOf), []);
    },
  },
  {
    // Spec 012 US5: the forms a line-by-line search missed.
    name: "an alias, a bracketed name and a read after a string with -- are problems too",
    fn: () => {
      const alias = privateProblems("local C = ns.CatchDB\nlocal x = C.private\n", "UI", folderOf);
      assert.deepEqual(alias.map((p) => p.line), [2], "alias");
      const bracket = privateProblems('local x = ns["CatchDB"].private\n', "UI", folderOf);
      assert.deepEqual(bracket.map((p) => p.line), [1], "bracketed name");
      const bracketKey = privateProblems('local C = ns.CatchDB\nlocal x = C["private"]\n', "UI", folderOf);
      assert.deepEqual(bracketKey.map((p) => p.line), [2], "bracketed key");
      const afterString = privateProblems('local s = "a -- b" local x = CatchDB.private\n', "UI", folderOf);
      assert.deepEqual(afterString.map((p) => p.line), [1], "after a string with --");
    },
  },
  {
    name: "the module's own folder and a file that does not parse report nothing",
    fn: () => {
      const text = 'local C = ns.CatchDB\nlocal a = C.private\nlocal b = ns["CatchDB"].private\n';
      assert.deepEqual(privateProblems(text, "CatchDB", folderOf), []);
      assert.deepEqual(privateProblems("local x = = CatchDB.private\n", "UI", folderOf), []);
    },
  },
];
