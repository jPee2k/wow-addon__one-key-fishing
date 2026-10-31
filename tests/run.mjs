// Runs the Lua tests: every *_test.lua under tests/ (one folder per area of the addon, any depth) in its own
// fresh Lua state, after tests/wow.lua (WoW API stubs); then the Node tests: every *_test.mjs under tests/, which
// exports `tests`, a list of { name, fn } (fn may be async). The layout is in docs/development.md.
//   npm test                      all test files
//   npm test -- lures             only the files whose path (relative to tests/) contains "lures"
//   npm test -- exchange/channel  one folder
//   OKF_SIM_NODES=1000 npm test -- sim_test   the channel simulation at that size (global SIM_NODES)
// Exits with code 1 when a test fails.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { ADDON_DIR, TOC, parseToc } from "../tools/addon.mjs";
import { getGlobalNumber, newState, run, setGlobalList, setGlobalNumber, setGlobalString } from "./lua.mjs";

const TESTS_DIR = path.dirname(fileURLToPath(import.meta.url));
// The filter is matched against the path relative to tests/, with forward slashes.
const filter = (process.argv[2] || "").replace(/\\/g, "/");
// The size of tests/exchange/channel/sim_test.lua, when given (a positive integer).
const simNodesText = process.env.OKF_SIM_NODES || "";
const simNodes = /^[1-9]\d*$/.test(simNodesText) ? Number(simNodesText) : null;

const tocFiles = parseToc(fs.readFileSync(path.join(ADDON_DIR, TOC), "utf8")).files;
const stubs = fs.readFileSync(path.join(TESTS_DIR, "wow.lua"), "utf8");
// Every file under tests/ (any depth), as a path relative to tests/ with forward slashes.
function walk(dir, prefix = "", out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = prefix + entry.name;
    if (entry.isDirectory()) {
      walk(path.join(dir, entry.name), `${rel}/`, out);
    } else {
      out.push(rel);
    }
  }
  return out;
}
const allFiles = walk(TESTS_DIR);
const matching = (suffix) => allFiles
  .filter((name) => name.endsWith(suffix) && (!filter || name.includes(filter)))
  .sort();
const testFiles = matching("_test.lua");
const nodeTestFiles = matching("_test.mjs");

if (testFiles.length + nodeTestFiles.length === 0) {
  console.error(`No test files${filter ? ` matching "${filter}"` : ""} in tests/`);
}

let passed = 0;
let failed = 0;
for (const name of testFiles) {
  console.log(name);
  const L = newState();
  setGlobalString(L, "ADDON_DIR", ADDON_DIR.replace(/\\/g, "/"));
  setGlobalList(L, "TOC_FILES", tocFiles);
  if (simNodes) {
    setGlobalNumber(L, "SIM_NODES", simNodes);
  }
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

for (const name of nodeTestFiles) {
  console.log(name);
  let tests;
  try {
    ({ tests } = await import(pathToFileURL(path.join(TESTS_DIR, name)).href));
  } catch (error) {
    console.log(`  FAIL ${name} could not be loaded: ${error.message}`);
    failed += 1;
    continue;
  }
  if (!Array.isArray(tests) || tests.length === 0) {
    console.log(`  FAIL ${name} exports no tests`);
    failed += 1;
    continue;
  }
  for (const { name: testName, fn } of tests) {
    try {
      await fn();
      console.log(`  ok   ${testName}`);
      passed += 1;
    } catch (error) {
      console.log(`  FAIL ${testName}\n${error && error.stack ? error.stack : error}`);
      failed += 1;
    }
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
// exitCode instead of process.exit(): the output above is fully written before Node exits.
process.exitCode = failed > 0 || testFiles.length + nodeTestFiles.length === 0 ? 1 : 0;
