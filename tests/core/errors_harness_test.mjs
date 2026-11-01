// tests/wow.lua with the error log: an error handed to the game's handler fails its test and, outside a test, stops
// the file, as an uncaught error did before ns.Safe caught the dispatchers' errors. Run by tests/run.mjs.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { newState, run, setGlobalList, setGlobalString } from "../lua.mjs";

const TESTS_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const stubs = fs.readFileSync(path.join(TESTS_DIR, "wow.lua"), "utf8");

// A fresh Lua state with the stubs, running `code` after them with `print` silenced (the inner test() lines are not
// this file's results); throws with the Lua error.
function runWithStubs(code) {
  const L = newState();
  setGlobalString(L, "ADDON_DIR", "");
  setGlobalList(L, "TOC_FILES", []);
  run(L, stubs, "@tests/wow.lua");
  run(L, `print = function() end\n${code}`, "@harness_case.lua");
}

export const tests = [
  {
    name: "an error handed on before a test stops the file",
    fn() {
      assert.throws(() => runWithStubs(`
        geterrorhandler()("stray")
        test("next", function() end)
      `), /stray/);
    },
  },
  {
    name: "an error handed on after the last test stops the file at the runner's check",
    fn() {
      assert.throws(() => runWithStubs(`
        test("last", function() end)
        geterrorhandler()("late")
        check_no_errors()
      `), /late/);
    },
  },
  {
    name: "a failing test reports the error handed on as well as its own failure",
    fn() {
      runWithStubs(`
        local out = {}
        print = function(text) table.insert(out, text) end
        test("both", function()
            geterrorhandler()("root cause")
            assert(false, "follow-on")
        end)
        local text = table.concat(out, "\\n")
        assert(text:find("root cause", 1, true), text)
        assert(text:find("follow-on", 1, true), text)
      `);
    },
  },
];
