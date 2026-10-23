// Runs the Lua tests: every tests/*_test.lua in its own fresh Lua state, after tests/wow.lua (WoW API stubs).
//   npm test             all test files
//   npm test -- lures    only the files whose name contains "lures"
// Exits with code 1 when a test fails.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ADDON_DIR, TOC, parseToc } from "../tools/addon.mjs";
import { getGlobalNumber, newState, run, setGlobalList, setGlobalString } from "./lua.mjs";

const TESTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const filter = process.argv[2];

const tocFiles = parseToc(fs.readFileSync(path.join(ADDON_DIR, TOC), "utf8")).files;
const stubs = fs.readFileSync(path.join(TESTS_DIR, "wow.lua"), "utf8");
const testFiles = fs.readdirSync(TESTS_DIR)
  .filter((name) => name.endsWith("_test.lua") && (!filter || name.includes(filter)))
  .sort();

if (testFiles.length === 0) {
  console.error(`No test files${filter ? ` matching "${filter}"` : ""} in tests/`);
}

let passed = 0;
let failed = 0;
for (const name of testFiles) {
  console.log(name);
  const L = newState();
  setGlobalString(L, "ADDON_DIR", ADDON_DIR.replace(/\\/g, "/"));
  setGlobalList(L, "TOC_FILES", tocFiles);
  try {
    run(L, stubs, "@tests/wow.lua");
    run(L, fs.readFileSync(path.join(TESTS_DIR, name), "utf8"), `@tests/${name}`);
    const filePassed = getGlobalNumber(L, "tests_passed");
    const fileFailed = getGlobalNumber(L, "tests_failed");
    passed += filePassed;
    failed += fileFailed;
    if (filePassed + fileFailed === 0) {
      console.log(`  FAIL ${name} ran no test() at all`);
      failed += 1;
    }
  } catch (error) {
    // An error outside test(): the rest of the file did not run.
    console.log(`  FAIL ${name} stopped: ${error.message}`);
    passed += getGlobalNumber(L, "tests_passed");
    failed += getGlobalNumber(L, "tests_failed") + 1;
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
// exitCode instead of process.exit(): the output above is fully written before Node exits.
process.exitCode = failed > 0 || testFiles.length === 0 ? 1 : 0;
