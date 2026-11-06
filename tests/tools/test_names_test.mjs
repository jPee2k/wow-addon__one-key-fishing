// tools/addon.mjs testNameProblem: a test file names its subject, never a module of its area (docs/development.md;
// specs/008-architecture-alignment contracts C5). Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import { testNameProblem } from "../../tools/addon.mjs";

const files = { Fishing: ["Bags", "Gear", "Skill"], Exchange: ["Comm", "Channel", "Share"], UI: ["CatchHere"] };
const moduleFiles = (folder) => files[folder] || [];

export const tests = [
  {
    name: "a test named after a module of its area is a problem, in any letter case and subfolder",
    fn: () => {
      assert.ok(testNameProblem("fishing/bags_test.lua", moduleFiles));
      assert.ok(testNameProblem("ui/catchhere_test.lua", moduleFiles));
      assert.ok(testNameProblem("exchange/comm/channel_test.lua", moduleFiles));
    },
  },
  {
    name: "a test that names its subject passes; tools and the harness are not checked",
    fn: () => {
      assert.equal(testNameProblem("fishing/lure_skill_test.lua", moduleFiles), null);
      assert.equal(testNameProblem("exchange/comm/channel_path_test.lua", moduleFiles), null);
      assert.equal(testNameProblem("tools/harvest_test.lua", moduleFiles), null);
      assert.equal(testNameProblem("wow_test.lua", moduleFiles), null);
    },
  },
];
