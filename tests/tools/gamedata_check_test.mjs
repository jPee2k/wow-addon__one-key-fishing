// tools/addon.mjs gameDataProblems: the npm run check rule that GameData/ holds data only (specs/008-architecture-
// alignment contracts C1). Run by tests/run.mjs (exports `tests`).
import assert from "node:assert/strict";
import { gameDataProblems } from "../../tools/addon.mjs";

const HEAD = "local _, ns = ...\nlocal GameData = ns.GameData or {}\nns.GameData = GameData\n";

export const tests = [
  {
    name: "a data-only GameData file passes",
    fn: () => {
      assert.deepEqual(gameDataProblems(`${HEAD}GameData.Lures = {\n    [6533] = { bonus = 100 }, -- Attractor\n}\n`),
        []);
    },
  },
  {
    name: "a function in a GameData file is a problem, with its line",
    fn: () => {
      const problems = gameDataProblems(`${HEAD}GameData.Get = function(id)\n    return id\nend\n`);
      assert.equal(problems.length, 1);
      assert.equal(problems[0].line, 4);
    },
  },
  {
    name: "an L lookup in a GameData file is a problem",
    fn: () => {
      assert.equal(gameDataProblems(`${HEAD}GameData.Name = ns.L["Apprentice"]\n`).length, 1);
      assert.equal(gameDataProblems(`${HEAD}local L = ns.L\nGameData.Name = L["Apprentice"]\n`).length, 2);
    },
  },
  {
    name: "another module in a GameData file is a problem",
    fn: () => {
      assert.equal(gameDataProblems(`${HEAD}GameData.Spells = ns.FISHING_SPELL_IDS\n`).length, 1);
      assert.equal(gameDataProblems(`${HEAD}GameData.Bags = ns.Bags\n`).length, 1);
    },
  },
  {
    name: "a call while the file loads is a problem (a name read from the client is no data)",
    fn: () => {
      assert.equal(gameDataProblems(`${HEAD}GameData.Name = { name = C_Spell.GetSpellName(7620) }\n`).length, 1);
      assert.equal(gameDataProblems(`${HEAD}GameData.Locale = GetLocale()\n`).length, 1);
      assert.equal(gameDataProblems(`${HEAD}GameData.L = ns["L"]\n`).length, 1);
      assert.equal(gameDataProblems(`${HEAD}GameData.Lures = setmetatable{ [1] = true }\n`).length, 1, "f{...}");
      assert.equal(gameDataProblems(`${HEAD}GameData.Name = GetText"x"\n`).length, 1, "f\"x\"");
      assert.equal(gameDataProblems(`${HEAD}GameData.Name = frame:GetName()\n`).length, 1, "a method");
      assert.equal(gameDataProblems(`${HEAD}GameData.Name = frame:Get"x"\n`).length, 1, "a method, no brackets");
    },
  },
  {
    name: "strings and comments are not code: UTF-8 names and words in comments pass",
    fn: () => {
      const text = `${HEAD}-- read by ns.FishingRanks in Skill.lua; no function here\n--[[ ns.L and function\n` +
        `in a block comment ]]\nGameData.NpcNames = {\n    [2626] = { ruRU = "Старик function ns.L" },\n}\n`;
      assert.deepEqual(gameDataProblems(text), []);
    },
  },
];
